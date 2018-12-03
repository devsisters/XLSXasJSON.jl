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
       r"(\[(\D+)\]$|\[Float64\]$)", x -> replace(x, r"(\[.+\])$|(\[\])$" => "")), # abc[Type]
  (Vector{Any}, r"(\[\])",           x -> replace(x, r"(\[.+\])$|(\[\])$" => ""))) # abc[]
# (JSONGroup, r"({})",           x -> replace(x, r"({.+\})$|({})$" => ""))) # abc{}

function parse_keyname(key)
    T = Any
    for (typ, reg, f) in JSONColumnType
        if occursin(reg, key)
            T = typ
            # Statically typed Vector
            if typ == (Array{T, 1} where T)
                x = match(reg, key).captures[2] |> Symbol
                T = @eval Vector{$x}
            else
                T = typ
            end
            key = f(key)
            break
        end
    end
    return T, key
end
