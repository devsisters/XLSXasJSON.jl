
"""
_column_to_pointer{T}(p::Pointer)

construct JSONPointer.Pointer with specified type 
"""
function _column_to_pointer(token_string::AbstractString)::Pointer
    if !startswith(token_string, JSONPointer.TOKEN_PREFIX)
        token_string = "/" * token_string
    end
    if endswith(token_string, "}")
        x = split(token_string, "{")
        p = Pointer(x[1])
        T = jsontype_to_juliatype(x[2][1:end-1])

        return Pointer{Array{T, 1}}(p.tokens)
    else 
        return Pointer(token_string)
    end
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
