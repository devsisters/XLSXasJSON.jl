const CS = JSON.CommonSerialization
const SC = JSON.StructuralContext


# removes indent for Vector
function compact_show_json(io, s, x::Array{T}) where T
    JSON.begin_array(io)
    for elt in x
        JSON.delimit(io)
        if isa(elt, Array{T2} where T2)
            compact_show_json(io, s, elt)
        else
            JSON.show_json(io, s, elt)
        end
    end
    JSON.end_array(io)
end
function dropnull(s)
    replace(s, r"(\"[\w]*\":null,)|(,?\"[\w]*\":null)" => "")
end

function write end
function write(file::Union{String, IO}, jws::JSONWorksheet; indent = 2, drop_null = false)
    open(file, "w") do io
        data = JSON.json(jws.data, indent)
        if drop_null
            data = dropnull(data)
        end

        Base.write(io, data)
    end
end
function write(file::Union{String, IO}, jws::JSONWorksheet, cols::Array{Symbol, 1}; kwargs...)
    write(file,
          JSONWorksheet(jws[cols], xlsxpath(jws), sheetnames(jws));
          kwargs...)
end