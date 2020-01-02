const TOKEN_PREFIX = '/'
"""
    JSONPointer(token)

Follows https://tools.ietf.org/html/rfc6901 standard

### Differences are 
- Index numbers starts from '1' instead of '0'  
- Declare type with '::T' notation at the end 

### Example
"""
struct JSONPointer 
    token::Tuple
    valuetype::DataType 
end
function JSONPointer(token::AbstractString)
    if !startswith(token, TOKEN_PREFIX) 
        throw(ArgumentError("JSONPointer must starts with '/' prefix"))
    end
    
    jk = convert(Array{Any, 1}, split(chop(token; head=1, tail=0), TOKEN_PREFIX))
    T = Any
    if occursin("::", jk[end])
        x = split(jk[end], "::")
        jk[end] = x[1]
        T = (x[2] == "Vector" ? "Vector{Any}" : x[2]) |> Meta.parse |> eval
    end
    @inbounds for i in 1:length(jk)
        if occursin(r"^\d+$", jk[i]) # index of a array
            jk[i] = parse(Int, string(jk[i]))
            if iszero(jk[i]) 
                throw(AssertionError("Julia uses 1-based indexing"))
            end
        end
    end

    JSONPointer(tuple(jk...), T) 
end

function empty_value(p::JSONPointer)
    VT = p.valuetype
    if VT <: Array 
        eltype(VT) <: Real ? eltype(VT)[] : 
        eltype(VT) <: AbstractString ? AbstractString[] :
        Any[]
    elseif VT <: Real 
        zero(VT) 
    else 
        missing
    end  
end

Base.Dict(p::JSONPointer) = create_by_pointer(Dict, p)
DataStructures.OrderedDict(p::JSONPointer) = create_by_pointer(OrderedDict, p)

function create_by_pointer(::Type{T}, p::JSONPointer) where T <: AbstractDict
    val = nothing

    @inbounds for i in length(p):-1:1
        k = p.token[i]
        if isa(k, Integer)
            tmp = Array{Any, 1}(missing, k)
            if i == length(p)
            else 
                tmp[k] = val
            end
            val = tmp 
        elseif isa(k, AbstractString)
            if i == length(p)
                val = T{String, Any}(k => empty_value(p))
            else 
                val = T{String, Any}(k => val)
            end
        end
    end
    return val
end

function create_by_pointer(::Type{T}, arr::Array) where T <: AbstractDict
    template = T(arr[1])
    if length(arr) > 1
        @inbounds for p in arr
            template[p] = empty_value(p)
        end
    end
    return template
end

for T in (Dict, OrderedDict)
    @eval Base.getindex(dict::$T{K,V}, p::JSONPointer) where {K, V} = getindex_by_pointer(dict, p)
    @eval Base.setindex!(dict::$T{K,V}, v, p::JSONPointer) where {K <: AbstractString, V} = setindex_by_pointer!(dict, v, p)
    @eval Base.setindex!(dict::$T{K,V}, v, p::JSONPointer) where {K <: Integer, V} = setindex_by_pointer!(dict, v, p)
end
function getindex_by_pointer(collection, p::JSONPointer, i = 1)
    val = getindex(collection, p.token[i])
    if i < length(p)
        val = getindex_by_pointer(val, p, i+1)    
    end
    return val
end

function setindex_by_pointer!(collection::T, v, p::JSONPointer) where T <: AbstractDict
    # if !isa(v, p.valuetype)
    #     @warn "'$(v)' is not matching valuetype of $(p)"
    # end
    prev = collection
    DT = OrderedDict{String, Any}

    @inbounds for (i, k) in enumerate(p.token)
        if isa(prev, AbstractDict) 
            DT = typeof(prev)
        end
        if isa(prev, Array)
            if !isa(k, Integer)
                throw(MethodError(setindex!, k))
            end 
            grow_array!(prev, k)
        else 
            if isa(k, Integer)
                throw(MethodError(setindex!, k))
            end
            if !haskey(prev, k)
                setindex!(prev, missing, k)
            end
        end

        if i < length(p) 
            tmp = getindex(prev, k)
            if ismissing(tmp)
                next_key = p.token[i+1]
                if isa(next_key, Integer)
                    new_data = Array{Any,1}(missing, next_key)
                else 
                    new_data = DT(next_key => missing)
                end
                setindex!(prev, new_data, k)
            end
            prev = getindex(prev, k)
        end
    end
    setindex!(prev, v, p.token[end])
end

function grow_array!(arr, target_size)
    x = target_size - length(arr) 
    if x > 0 
        T = eltype(arr)
        new_arr = Array{T, 1}(undef, x)
        new_arr .= T <: Real ? zero(T) : missing
        append!(arr, new_arr)
    end
    return arr
end

Base.length(x::JSONPointer) = length(x.token)

function Base.show(io::IO, x::JSONPointer)
    print(io, "Pointer(\"/", join(x.token, "/"), "\", ", 
                x.valuetype, ")")
end

