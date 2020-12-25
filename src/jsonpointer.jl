
function parse_column_to_pointer(data::AbstractArray)
    pointers = Array{Pointer,1}(undef, length(data))
    for (i, el) in enumerate(data)
        if !startswith(el, JSONPointer.TOKEN_PREFIX)
            el = "/" * el
        end
        if endswith(el, "}")
            x = split(el, "{")
            p = Pointer(x[1])
            T = jsontype_to_juliatype(x[2][1:end-1])
            p = Pointer{Array{T, 1}}(p.tokens)
        else 
            p = Pointer(el)
        end
        pointers[i] = p
    end
    return pointers
end

function jsontype_to_juliatype(t)
    if t == "string"
        return String
    elseif t == "number"
        return Float64
    # JSON does not have distinct types for integers and floating-point values
    # but Excel does, and distinguishing integer is useful for many things.
    elseif t == "integer" 
        return Int
    elseif t == "object"
        return OrderedCollections.OrderedDict{String,Any}
    elseif t == "array"
        return Vector{Any}
    elseif t == "boolean"
        return Bool
    elseif t == "null"
        return Missing
    else
        error(
            "You specified a type that JSON doesn't recognize! Instead of " *
            "`::$t`, you must use one of `::string`, `::number`, " *
            "`::object`, `::array`, `::boolean`, or `::null`."
        )
    end
end
