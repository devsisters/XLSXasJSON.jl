struct JSONPointer 
    key::Tuple
    valuetype::DataType 
end
function JSONPointer(key, valuetype = Any; spliter::Char = '/')
    if isa(key, AbstractString)
        jk = convert(Array{Any, 1}, split(key, spliter))
        for (i, k) in enumerate(jk)
            if occursin(REG_VECTOR, k)
                jk[i] = replace(k, REG_VECTOR => "")
                valuetype = vector_element_datatype(key)
            elseif occursin(r"^\d+$", k) # index of a array
                jk[i] = parse(Int, string(k))
                if iszero(jk[i]) 
                    throw(AssertionError("Julia uses 1-based indexing"))
                end
            end
        end
        filter!(!isempty, jk)
    else 
        jk = Any[key]
    end

    JSONPointer(tuple(jk...), valuetype) 
end

# 삭제예정
function gradiant(p::JSONPointer)
    x = Array{JSONPointer, 1}(undef, length(p))
    for i in 1:length(p)
        x[i] = if i == length(p)
            p
        else
            JSONPointer(p.key[1:i])
        end
    end
    x
end  

Base.Dict(p::JSONPointer) = create_by_pointer(Dict, p)
DataStructures.OrderedDict(p::JSONPointer) = create_by_pointer(OrderedDict, p)

function create_by_pointer(::Type{T}, p::JSONPointer) where T <: AbstractDict
    val = nothing
    for i in length(p):-1:1
        k = p.key[i]
        if isa(k, Integer)
            if i == length(p)
                # TODO; ()array type
                val = Array{Any, 1}(missing, k)
            else 
                tmp = Array{Any, 1}(missing, k)
                tmp[k] = val
                val = tmp 
            end
        elseif isa(k, AbstractString)
            if i == length(p)
                # TODO; ()array type
                val = T{String, Any}(k => missing)
            else 
                val = T{String, Any}(k => val)
            end
        end
    end
    return val
end

for T in (Dict, OrderedDict)
    @eval Base.getindex(dict::$T{K,V}, p::JSONPointer) where {K, V} = getindex_by_pointer(dict, p)
    @eval Base.setindex!(dict::$T{K,V}, v, p::JSONPointer) where {K, V} = setindex_by_pointer!(dict, v, p)
end
function getindex_by_pointer(collection, p::JSONPointer, i = 1)
    val = getindex(collection, p.key[i])
    if i < length(p)
        val = getindex_by_pointer(val, p, i+1)    
    end
    return val
end

function setindex_by_pointer!(collection, v, p::JSONPointer)
    if !isa(v, p.valuetype)
        @warn "'$(v)' is not matching valuetype of $(p)"
    end
    prev = collection
    # TODO 최상단이 Array일 경우에도 올바른 Dict타입 찾아주기
    DT = isa(prev, AbstractDict) ? typeof(prev) : OrderedDict{String, Any}

    for (i, k) in enumerate(p.key)
        if isa(prev, AbstractArray)
            if !isa(k, Integer)
                throw(AssertionError("Array를 Dict로 변환 불가"))
            end 
            grow_array!(prev, k)
        else 
            if isa(k, Integer)
                throw(AssertionError("Dict를 Array로 변환 불가"))
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
        # if i == length(p)
        #     setindex!(prev, v, k)
        # end
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
    print(io, "Pointer(\"", join(x.key, "/"), "\", ", 
                x.valuetype, ")\n")
end

