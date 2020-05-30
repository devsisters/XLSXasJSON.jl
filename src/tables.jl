# declare that MatrixTable is a table
Tables.istable(::Type{<:JSONWorksheet}) = true
Tables.isrowtable(::Type{<:JSONWorksheet}) = true
Tables.rowaccess(::JSONWorksheet) = true
Tables.rows(jws::JSONWorksheet) = data(jws)
# function Tables.columns(jws::JSONWorksheet2) 
# end

Tables.columnnames(jws::JSONWorksheet) = getfield(jws, :pointer)
Tables.getcolumn(jws::JSONWorksheet, p::JSONPointer) = jws[:, p]
Tables.getcolumn(jws::JSONWorksheet, nm::Symbol) = jws[:, JSONPointer(nm)]

function Tables.schema(jws::JSONWorksheet) 
    t = Array{DataType, 1}(undef, size(jws, 2))
    for (i, col) in enumerate(Tables.columnnames(jws))
        x = typeof.(jws[:, col])
        t[i] = length(unique(x)) == 1 ? x[1] : Any
    end
    Tables.Schema(map(el -> "/"*join(el.token,"/"), Tables.columnnames(jws)), t)
end