JSON.json(jws::JSONWorksheet) = JSON.json(data(jws))
JSON.json(jws::JSONWorksheet, indent) = JSON.json(data(jws), indent)

function dropnull(s)
    replace(s, r"(\"[\w]*\":null,)|(,?\"[\w]*\":null)" => "")
end

function write end
function write(file::Union{String, IO}, jws::JSONWorksheet; indent = 2, drop_null = false)
    open(file, "w") do io
        data = JSON.json(jws, indent)
        if drop_null
            data = dropnull(data)
        end

        Base.write(io, data)
    end
end