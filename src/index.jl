# simplified form of https://github.com/JuliaData/DataFrames.jl/blob/master/src/other/index.jl
abstract type AbstractIndex end

struct Index <: AbstractIndex   # an OrderedDict would be nice here...
    lookup::Dict{AbstractString, Int}      # name => names array position
    names::Vector{AbstractString}
end

function Index(names::Array{T, 1}) where T <: AbstractString
    @assert allunique(names) "names must be unique check for $names"
    lookup = Dict{AbstractString, Int}(zip(names, 1:length(names)))
    Index(lookup, names)
end

Index() = Index(Dict{AbstractString, Int}(), String[])
Base.length(x::Index) = length(x.names)
Base.names(x::Index) = copy(x.names)
_names(x::Index) = x.names
Base.copy(x::Index) = Index(copy(x.lookup), copy(x.names))
Base.isequal(x::AbstractIndex, y::AbstractIndex) = _names(x) == _names(y) # it is enough to check names
Base.:(==)(x::AbstractIndex, y::AbstractIndex) = isequal(x, y)

Base.haskey(x::Index, key::AbstractString) = haskey(x.lookup, key)
Base.haskey(x::Index, key::Integer) = 1 <= key <= length(x.names)
Base.haskey(x::Index, key::Bool) =
    throw(ArgumentError("invalid key: $key of type Bool"))
Base.keys(x::Index) = names(x)

@inline Base.getindex(x::AbstractIndex, idx::Bool) = throw(ArgumentError("invalid index: $idx of type Bool"))

@inline function Base.getindex(x::AbstractIndex, idx::Integer)
    if !(1 <= idx <= length(x))
        throw(BoundsError("attempt to access a Index with $(length(x)) columns at index $idx"))
    end
    Int(idx)
end

@inline function Base.getindex(x::AbstractIndex, idx::AbstractVector{Int})
    isempty(idx) && return idx
    minidx, maxidx = extrema(idx)
    if minidx < 1
        throw(BoundsError("attempt to access a Index with $(length(x)) columns at index $minidx"))
    end
    if maxidx > length(x)
        throw(BoundsError("attempt to access a Index with $(length(x)) columns at index $maxidx"))
    end
    allunique(idx) || throw(ArgumentError("Elements of $idx must be unique"))
    idx
end

@inline function Base.getindex(x::AbstractIndex, idx::AbstractRange{Int})
    isempty(idx) && return idx
    minidx, maxidx = extrema(idx)
    if minidx < 1
        throw(BoundsError("attempt to access a Index with $(length(x)) columns at index $minidx"))
    end
    if maxidx > length(x)
        throw(BoundsError("attempt to access a Index with $(length(x)) columns at index $maxidx"))
    end
    allunique(idx) || throw(ArgumentError("Elements of $idx must be unique"))
    idx
end

@inline Base.getindex(x::AbstractIndex, idx::AbstractRange{<:Integer}) = getindex(x, collect(Int, idx))
@inline Base.getindex(x::AbstractIndex, ::Colon) = Base.OneTo(length(x))

@inline function Base.getindex(x::AbstractIndex, idx::AbstractVector{<:Integer})
    if any(v -> v isa Bool, idx)
        throw(ArgumentError("Bool values except for AbstractVector{Bool} are not allowed for column indexing"))
    end
    getindex(x, Vector{Int}(idx))
end

@inline Base.getindex(x::AbstractIndex, idx::AbstractRange{Bool}) = getindex(x, collect(idx))

@inline function Base.getindex(x::AbstractIndex, idx::AbstractVector{Bool})
    length(x) == length(idx) || throw(BoundsError(x, idx))
    findall(idx)
end

# catch all method handling cases when type of idx is not narrowest possible, Any in particular
@inline function Base.getindex(x::AbstractIndex, idxs::AbstractVector)
    isempty(idxs) && return Int[] # special case of empty idxs
    if idxs[1] isa Real
        if !all(v -> v isa Integer && !(v isa Bool), idxs)
            throw(ArgumentError("Only Integer values allowed when indexing by vector of numbers"))
        end
        return getindex(x, convert(Vector{Int}, idxs))
    end
    idxs[1] isa AbstractString && return getindex(x, convert(Vector{AbstractString}, idxs))
    throw(ArgumentError("idxs[1] has type $(typeof(idxs[1])); "*
                        "Only Integer or String values allowed when indexing by vector"))
end

@inline function Base.getindex(x::AbstractIndex, rx::Regex)
    getindex(x, filter(name -> occursin(rx, String(name)), _names(x)))
end

"""
    fuzzymatch(l::Dict, idx::AbstractString)
# Fuzzy matching rules:
# 1. ignore case
# 2. maximum Levenshtein distance is 2
# 3. always show matches with 0 difference (wrong case)
# 4. on top of 3. do not show more than 8 matches in total
# Returns candidates ordered by (distance, name) pair
"""
function fuzzymatch(l::Dict{AbstractString, Int}, idx::AbstractString)
        idxs = uppercase(idx)
        dist = [(REPL.levenshtein(uppercase(x), idxs), x) for x in keys(l)]
        sort!(dist)
        c = [count(x -> x[1] <= i, dist) for i in 0:2]
        maxd = max(0, searchsortedlast(c, 8) - 1)
        [s for (d, s) in dist if d <= maxd]
end

@inline function lookupname(l::Dict{AbstractString, Int}, idx::AbstractString)
    i = get(l, idx, nothing)
    if i === nothing
        candidates = fuzzymatch(l, idx)
        if isempty(candidates)
            throw(ArgumentError("column name :$idx not found in the data frame"))
        end
        candidatesstr = join(string.(':', candidates), ", ", " and ")
        throw(ArgumentError("column name :$idx not found in the data frame; " *
                            "existing most similar names are: $candidatesstr"))
    end
    i
end

@inline Base.getindex(x::Index, idx::AbstractString) = lookupname(x.lookup, idx)
@inline function Base.getindex(x::Index, idx::AbstractVector{AbstractString})
    allunique(idx) || throw(ArgumentError("Elements of $idx must be unique"))
    [lookupname(x.lookup, i) for i in idx]
end
