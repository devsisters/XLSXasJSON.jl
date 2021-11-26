
"""
    JSONWorkbook(file::AbstractString; start_line = 1)

`start_line` of each sheets are considered as JSONPointer for data structure. 
And each sheets are pared to `Array{OrderedDict, 1}` 

# Constructors
```julia
JSONWorkbook("Example.xlsx")
```

# Arguments
arguments are applied to all Worksheets within Workbook.

- `row_oriented` : if 'true'(the default) it will look for colum names in '1:1', if `false` it will look for colum names in 'A:A' 
- `start_line` : starting index of position of columnname.
- `squeeze` : squeezes all rows of Worksheet to a singe row.
- `delim` : a String or Regrex that of deliminator for converting single cell to array.

"""
mutable struct JSONWorkbook
    xlsxpath::AbstractString
    sheets::Vector{JSONWorksheet}
    sheetindex::Index
end

function JSONWorkbook(xf::XLSX.XLSXFile, v::Vector{JSONWorksheet})
    wsnames = sheetnames.(v)
    index = Index(wsnames)
    JSONWorkbook(xf.filepath, v, index)
end
# same kwargs for all sheets
function JSONWorkbook(xf::XLSX.XLSXFile, sheets = XLSX.sheetnames(xf); kwargs...)
    v = Array{JSONWorksheet, 1}(undef, length(sheets))
    @inbounds for (i, s) in enumerate(sheets)
        v[i] = JSONWorksheet(xf, s; kwargs...)
    end
    close(xf)

    JSONWorkbook(xf, v)
end
# Different Kwargs per sheet
function JSONWorkbook(xlsxpath::AbstractString, sheets, kwargs_per_sheet::Dict)
    xf = XLSX.readxlsx(xlsxpath)

    v = Array{JSONWorksheet, 1}(undef, length(sheets))
    @inbounds for (i, s) in enumerate(sheets)
        v[i] = JSONWorksheet(xf, s; kwargs_per_sheet[s]...)
    end
    close(xf)

    JSONWorkbook(xf, v)
end
function JSONWorkbook(xlsxpath, sheets; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    JSONWorkbook(xf, sheets; kwargs...)
end
function JSONWorkbook(xlsxpath; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    JSONWorkbook(xf; kwargs...)
end

# JSONWorkbook fallback functions
hassheet(jwb::JSONWorkbook, s::AbstractString) = haskey(jwb.sheetindex, s)
hassheet(jwb::JSONWorkbook, s::Symbol) = haskey(jwb.sheetindex, string(s))
sheetnames(jwb::JSONWorkbook) = names(jwb.sheetindex)
xlsxpath(jwb::JSONWorkbook) = jwb.xlsxpath

getsheet(jwb::JSONWorkbook, i) = jwb.sheets[i]
getsheet(jwb::JSONWorkbook, s::AbstractString) = getsheet(jwb, jwb.sheetindex[s])
getsheet(jwb::JSONWorkbook, s::Symbol) = getsheet(jwb, jwb.sheetindex[string(s)])
Base.getindex(jwb::JSONWorkbook, i::UnitRange) = getsheet(jwb, i)
Base.getindex(jwb::JSONWorkbook, i::Integer) = getsheet(jwb, i)
Base.getindex(jwb::JSONWorkbook, s::AbstractString) = getsheet(jwb, s)
Base.getindex(jwb::JSONWorkbook, s::Symbol) = getsheet(jwb, string(s))

Base.length(jwb::JSONWorkbook) = length(jwb.sheets)
Base.lastindex(jwb::JSONWorkbook) = length(jwb.sheets)

Base.setindex!(jwb::JSONWorkbook, jws::JSONWorksheet, i1::Int) = setindex!(jwb.sheets, jws, i1)
Base.setindex!(jwb::JSONWorkbook, jws::JSONWorksheet, s::Symbol) = setindex!(jwb, jws, string(s))
Base.setindex!(jwb::JSONWorkbook, jws::JSONWorksheet, s::AbstractString) = setindex!(jwb.sheets, jws, jwb.sheetindex[s])

function Base.deleteat!(jwb::JSONWorkbook, i::Integer)
    deleteat!(getfield(jwb, :sheets), i)
    s = sheetnames.(getfield(jwb, :sheets))
    setfield!(jwb, :sheetindex, Index(s))
    jwb
end
Base.deleteat!(jwb::JSONWorkbook, sheet::Symbol) = deleteat!(jwb, string(sheet))
function Base.deleteat!(jwb::JSONWorkbook, sheet::AbstractString)
    i = getfield(jwb, :sheetindex)[sheet]
    deleteat!(jwb, i)
end

Base.iterate(jwb::JSONWorkbook) = iterate(jwb, 1)
function Base.iterate(jwb::JSONWorkbook, st)
    st > length(jwb) && return nothing
    return (jwb[st], st + 1)
end

## Display
function Base.summary(io::IO, jwb::JSONWorkbook)
    @printf(io, "JSONWorkbook(\"%s\") containing %i Worksheets\n",
                basename(xlsxpath(jwb)), length(jwb))
end
function Base.show(io::IO, jwb::JSONWorkbook)
    summary(io, jwb)
    @printf(io, "%6s %-15s\n", "index", "name")
    println(io, "-"^(6+1+15+1))

    index = sort(OrderedDict(jwb.sheetindex.lookup); byvalue = true)
    for el in index
        name = string(el[1])
        @printf(io, "%6s %-15s\n", el[2], string(el[1]))
    end
end

