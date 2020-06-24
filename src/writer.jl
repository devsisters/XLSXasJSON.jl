JSON.json(jws::JSONWorksheet) = JSON.json(data(jws))
JSON.json(jws::JSONWorksheet, indent) = JSON.json(data(jws), indent)

function dropnull(s)
    replace(s, r"(\"[\w]*\":null,)|(,?\"[\w]*\":null)" => "")
end

function write(file::Union{String, IO}, jws::JSONWorksheet; indent = 2, drop_null = false)
    open(file, "w") do io
        data = JSON.json(jws, indent)
        if drop_null
            data = dropnull(data)
        end

        Base.write(io, data)
    end
end

function write(path::String, jwb::JSONWorkbook; kwargs...)
    f = splitext(basename(xlsxpath(jwb)))[1]
    for s in sheetnames(jwb)
        write(joinpath(path, "$(f)_$(s).json"), jwb[s]; kwargs...)
    end
end

function write_xlsx(file::String, jwb::JSONWorkbook)
    XLSX.openxlsx(file, mode="w") do xf

        for (i, s) in enumerate(sheetnames(jwb))
            jws = jwb[s]
            sheet = XLSX.addsheet!(xf, s)

            labels = map(el -> "/" * join(el.token, "/"), jws.pointer)
            columns = map(p -> get.(jws.data, Ref(p), missing), jws.pointer)

            XLSX.writetable!(sheet, columns, labels, anchor_cell=XLSX.CellRef("A1"))

        end
    end
end