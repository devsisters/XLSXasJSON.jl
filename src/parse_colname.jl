const VEC_REGEX = r"\((.*?)\)" # key(), key(T)
const VECDICT_REGEX = r"\[(.*?)\]" # [idx,key]

"""
    determine_datatype  


"""
function determine_datatype(k)::Tuple{String,DataType}
    # [idx,key]
    if occursin(VECDICT_REGEX, k)
        k = chop(k; head=1, tail=1) #remove []
        k2 = split(k, ",")
        @assert length(k2) == 2 "Specify index of Vector{Dict} data in $(k)"

        TV = Vector{OrderedDict{String,Any}}
    # key(), key(T)
    elseif occursin(VEC_REGEX, k)
        TV = finddatatype_in_vector(k)
        k = replace(k, VEC_REGEX => "")
    else # empty string for Any value
        TV = Any
    end
    (k ,TV)
end

function finddatatype_in_vector(k)
    m = match(VEC_REGEX, k)
    t = uppercasefirst(m.captures[1])
    if t == ""
        Vector{Any}
    elseif t == "Float"
        Vector{Float64}
    else
        @eval Vector{$(Symbol(t))}
    end
end