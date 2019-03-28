"""
    JSONColumnType

* Use `phones.type` for values to be stored as a Dict
* Use `aliases[]` and seperate values by `a;b;c` for values to be stored as a Vector
* Use `phones[1].type` for values to be stored as Vector{Dict}

For more detailed information, see the examples in README
"""
const JSONColumnType = (
  (Vector{Dict},r"\[(\d+)\]\.(.+)$", x -> split(x, ".")), # abc[1].key
  (Dict,        r"\.(.+)",           x -> split(x, ".")), #abc.key
  (Vector{T} where T,
                    r"(\[(\D+)\]$)",   x -> replace(x, r"(\[.+\])" => "")), # abc[Type]
  (Vector{Float64}, r"(\[Float64\]$)", x -> replace(x, r"(\[.+\])" => "")), # abc[Float64]       
  (Vector{Any},     r"(\[\])",         x -> replace(x, r"(\[.+\])$|(\[\])$" => ""))) # abc[]
# (JSONGroup, r"({})",           x -> replace(x, r"({.+\})$|({})$" => ""))) # abc{}

function assign_jsontype(key)
    T = Any
    for (typ, reg, f) in JSONColumnType
        if occursin(reg, key)
            T = typ
            # Statically typed Vector
            if typ == (Array{T, 1} where T)
                x = match(reg, key).captures[2] |> Symbol

                T = try 
                        @eval Vector{$x}
                    catch
                        throw(ArgumentError("$x from column `$key` is not a Julia type"))
                    end
            else
                T = typ
            end
            break
        end
    end
    return T
end

function assign_jsontype(colnames::Array{T, 1}) where T
    d = OrderedDict{Int, Any}()
    container = OrderedDict()
    for (i, x) in enumerate(colnames)
        T2 = assign_jsontype(x)

        if T2 <: Dict
            kk = split(x, ".")
            if haskey(container, kk[1])
                container[kk[1]][kk[2]] = []
            else
                container[kk[1]] = OrderedDict{String, Any}(kk[2] => missing)
            end
        elseif T2 <: Array{Dict, 1}
            kk = split(x, ".")
            index = match(r"(\[(\d+)\])", kk[1]).captures[2] |> x -> parse(Int, x) +1

            kk[1] = replace(kk[1], r"(\[.+\])" => "")
            if !haskey(container, kk[1])
                container[kk[1]] = OrderedDict[]
            end

            kk = [kk[1], index, kk[2]]

        elseif T2 <: Array{T3, 1} where T3
            kk = replace(x, r"(\[.+\])|(\[\])" => "")
            container[kk] = missing
        else
            kk = x
            container[kk] = missing
        end
        d[i] = (T2, kk)
    end

    return d, container
end
