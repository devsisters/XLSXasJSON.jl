<<<<<<< Updated upstream
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
=======
Tables.istable(::Type{<:JSONWorksheet}) = true
Tables.isrowtable(::Type{<:JSONWorksheet}) = true
Tables.rowaccess(::Type{<:JSONWorksheet}) = true


# column interface
Tables.columnaccess(::Type{<:JSONWorksheet}) = true
Tables.columns(m::JSONWorksheet) = m[:, :]
# required Tables.AbstractColumns object methods
# Tables.getcolumn(m::JSONWorksheet, ::Type{T}, col::Int, nm::Symbol) where {T} = matrix(m)[:, col]
Tables.getcolumn(m::JSONWorksheet, p::Pointer) = m[:, p]
Tables.getcolumn(d::AbstractDict, p::Pointer) = d[p]
Tables.getcolumn(m::JSONWorksheet, i::Int) = m[:, i]
Tables.columnnames(m::JSONWorksheet) = keys(m)

# schema is column names and types
# function Tables.schema(jws::JSONWorksheet)
#     Tables.Schema(keys(jws), eltype.(keys(jws)))
# end
>>>>>>> Stashed changes
