JSON.json(jws::JSONWorksheet) = JSON.json(data(jws))
JSON.json(jws::JSONWorksheet, indent) = JSON.json(data(jws), indent)

function write(file::Union{String, IO}, jws::JSONWorksheet; indent = 2, drop_null = false)
    open(file, "w") do io
        data = JSON.json(jws, indent)
        # drop null array such as [null, null, ....] 
        if drop_null
            data = replace(data, r"(\"[\w]*\":null,)|(,?\"[\w]*\":null)" => "")
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

function write_xlsx(file::String, jwb::JSONWorkbook; delim = ";", anchor_cell = "A1")
    XLSX.openxlsx(file, mode="w") do xf

        for (i, s) in enumerate(sheetnames(jwb))
            jws = jwb[s]
            if i == 1 
                sheet = xf[1]
                XLSX.rename!(sheet, s)
            else
                sheet = XLSX.addsheet!(xf, s)
            end

            labels = map(el -> "/" * join(el.tokens, "/"), jws.pointer)
            columns = []
            for p in jws.pointer
                data = get.(jws.data, Ref(p), missing)
                if eltype(data) <: Array
                    data = join.(data, delim)
                end 
                push!(columns, data)
            end
            
            XLSX.writetable!(sheet, columns, labels, anchor_cell=XLSX.CellRef(anchor_cell))
        end
    end
end