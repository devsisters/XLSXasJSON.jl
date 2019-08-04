"""
    determine_jsonvalue


"""
function determine_jsonvalue(k)::Tuple{String,DataType}
    function _vectordatatype(k)
        m = match(r"\((.*?)\)", k)
        t = uppercasefirst(m.captures[1])
        if t == ""
            Vector{Any}
        elseif t == "Float"
            Vector{Float64}
        else
            @eval Vector{$(Symbol(t))}
        end
    end
    reg_vecdict = r"\[(.*?)\]"
    reg_vec = r"\((.*?)\)"
    # []
    if occursin(reg_vecdict, k)
        k = chop(k; head=1, tail=1) #remove []
        k = split(k, ",")
        @assert length(k) == 2 "Specify index of Vector{Dict} data in $(k[1])"
        if occursin(reg_vec, k[2])
            k2 = replace(k[2], reg_vec => "")
            T = _vectordatatype(k[2])
            TV = OrderedDict{String,T}
        else
            k2 = k[2]
            TV = OrderedDict{String,Any}
        end
        k = parse(Int, k[1])
    # ()
    elseif occursin(reg_vec, k)
        TV = _vectordatatype(k)
        k = replace(k, reg_vec => "")
    else # empty string for Any value
        TV = Any
    end
    (k ,TV)
end

"""
    construct_row(col_names::Vector)

"""
function construct_row(col_names)

    empty_row = OrderedDict{String, Any}()

    for col in col_names
        mk = split(col, ".")
        target = empty_row
        for (i, k) in enumerate(mk)
            if i > 1
                target = target[mk[i-1]]
            end

            if i == length(mk)
                k, TV = determine_jsonvalue(k)
                @assert ismissing(get(target, k, missing)) "{$k: $TV} is being overwritten, check for duplicated name"
            else
                TV = Any
            end
            v = get(target, k, OrderedDict{Any, TV}())
            setindex!(target, v, k)
        end
    end
    return empty_row
end

function find_target(d::AbstractDict, col)
    mk = split(col, ".")
    target = get(d, mk[1], nothing)
    for i in 2:length(mk)
        target = get(target, mk[i], nothing)
    end
    @assert !isnothing(target) "could not find `$col` in $d"
    return target
end
