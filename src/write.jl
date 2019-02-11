const CS = JSON.CommonSerialization
const SC = JSON.StructuralContext

function JSON.show_json(io::SC, s::CS, jws::JSONWorksheet)
    JSON.begin_array(io)
    for (i, row) in enumerate(eachrow(jws))
        JSON.indent(io)
        JSON.begin_object(io)
        for el in pairs(row)
            if isa(el[2], Array{T} where T <: AbstractDict)
                JSON.show_pair(io, s, el)
            elseif isa(el[2], Array{T} where T)
                JSON.show_key(io, el[1])
                JSON.indent(io)
                compact_show_json(io, s, el[2])
            else
                JSON.show_pair(io, s, el)
            end
        end
        JSON.end_object(io)
        i != nrow(jws) && JSON.delimit(io)
    end
    JSON.end_array(io)
end
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


function write end
function write(file::Union{String, IO}, jws::JSONWorksheet; indent = 2)
    open(file, "w") do io
        Base.write(io, JSON.json(jws, indent))
    end
end
function write(file::Union{String, IO}, jws::JSONWorksheet, cols::Array{Symbol, 1}; kwargs...)
    write(file,
          JSONWorksheet(jws[cols], xlsxpath(jws), sheetnames(jws));
          kwargs...)
end
