const REG_VECTOR = r"(\(\))|(\(Float64\))|(\(Float\))|(\(Int\))|(\(String\))"

function vec_element_datatype(key)
    m = match(REG_VECTOR, key)
    T = m.match == "()" ? Any :
            lowercase(m.match) == "(int)" ? Int :
            lowercase(m.match) == "(float)" ? Float64 : 
            lowercase(m.match) == "(float64)" ? Float64 : 
            lowercase(m.match) == "(string)" ? AbstractString : 
            throw(MethodError(vec_element_datatype, key))
    return Array{T, 1}
end

const TOKEN_PREFIX = '/'
"""
    JSONPointer

Follows https://tools.ietf.org/html/rfc6901 standard

# Differences are 
- Index numbers starts from '1' instead of '0'  
- '()', '(Int)', '(Float)', '(String)' will evaluate Json value to Array 

# Example
"""
struct JSONPointer 
    key::Tuple
    valuetype::DataType 
end
function JSONPointer(key::AbstractString, valuetype = Any)
    if !startswith(key, TOKEN_PREFIX) 
        throw(ArgumentError("JSONPointer must starts with '/' prefix"))
    end
    if isa(key, AbstractString)
        jk = convert(Array{Any, 1}, split(chop(key; head=1, tail=0), TOKEN_PREFIX))
        @inbounds for i in 1:length(jk)
            if occursin(REG_VECTOR, jk[i])
                jk[i] = replace(jk[i], REG_VECTOR => "")
                valuetype = vec_element_datatype(key)
            end 
            if occursin(r"^\d+$", jk[i]) # index of a array
                jk[i] = parse(Int, string(jk[i]))
                if iszero(jk[i]) 
                    throw(AssertionError("Julia uses 1-based indexing"))
                end
            end
        end
        isempty(jk[end]) && pop!(jk)
    end

    JSONPointer(tuple(jk...), valuetype) 
end

function empty_value(p::JSONPointer)
    VT = p.valuetype
    if VT <: Array 
        eltype(VT) <: Real ? zeros(eltype(VT), 1) : 
        eltype(VT) <: AbstractString ? AbstractString[""] :
        Any[missing]
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
        k = p.key[i]
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
    val = getindex(collection, p.key[i])
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
    # TODO 최상단이 Array일 경우에도 올바른 Dict타입 찾아주기
    DT = isa(prev, AbstractDict) ? typeof(prev) : OrderedDict{String, Any}

    @inbounds for (i, k) in enumerate(p.key)
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
                next_key = p.key[i+1]
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
    setindex!(prev, v, p.key[end])
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

Base.length(x::JSONPointer) = length(x.key)

function Base.show(io::IO, x::JSONPointer)
    print(io, "Pointer(\"/", join(x.key, "/"), "\", ", 
                x.valuetype, ")")
end

