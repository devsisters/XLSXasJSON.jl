
# 이거 적절한 이름이??? 일단 개념은 여러 row를 1개로 묶어 주는 것
abstract type JSONGroup end

"""
    JSONColumnType
XLSXasJSON에서 사용 가능한 JASONData 규칙
"""
const JSONColumnType = (
  (Vector{Dict},r"\[(\d+)\]\.(.+)$", x -> split(x, ".")), # abc[1].key
  (Dict,        r"\.(.+)",           x -> split(x, ".")), #abc.key
  (Vector{T} where T,
       r"(\[(\D+)\]$|\[Float64\]$)", x -> replace(x, r"(\[.+\])$|(\[\])$" => "")), # abc[Type]
  (Vector{Any}, r"(\[\])",           x -> replace(x, r"(\[.+\])$|(\[\])$" => "")), # abc[]
  (JSONGroup, r"({})",           x -> replace(x, r"({.+\})$|({})$" => ""))) # abc{}

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
