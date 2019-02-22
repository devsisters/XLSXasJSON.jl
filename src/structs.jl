"""
    Able to use other string as delimiter by changing values of `DELIM`

push!(XLSXasJSON.DELIM, ",")
"""
const DELIM = [";"]

"""
What is the easiest way to organize and edit your Excel data?
Lists of simple objects seem a natural fit for a row oriented sheets.
Single objects with more complex structure seem more naturally presented as
column oriented sheets.
Doesn't really matter which orientation you use,
the module allows you to speciy a row or column orientation;
basically, where your keys are located: row 1 or column 1.

** Keys and values **

* Row or column 1 contains `JSONColumnType`
* Remaining rows/columns contain values for those keys
* Use `phones.type` for values to be stored as a Dict
* Use `aliases[]` and seperate values by `a;b;c` for values to be stored as a Vector

**Constructors**

```julia
JSONWorksheet(xlsxpath::String, sheet)
JSONWorksheet(xlsxpath::String, sheet;
          start_line=1, row_oriented::Bool=false, compact_to_singleline::Bool=false)
```

**Arguments**

* `xlsxpath` : full path to .xlsx or .xlsm file. .xls is not supported
* `sheet` : Index number of sheet or Nmae of sheet
* `row_oriented` : default is true for row oriendted data
* `start_line` : ignore rows smaller than `start_line`
* `compact_to_singleline` :

"""
mutable struct JSONWorksheet <: AbstractDataFrame
    data::DataFrame
    xlsxpath::AbstractString
    sheetname::Symbol
end
function JSONWorksheet(data::DataFrame, xlsxpath, sheet)
    JSONWorksheet(data, xlsxpath, Symbol(sheet))
end
function JSONWorksheet(arr::Array{T}, xlsxpath, sheet) where T
    data = parse_special_dataframe(arr)
    JSONWorksheet(data, xlsxpath, sheet)
end
function JSONWorksheet(xf::XLSX.XLSXFile, sheet;
                       start_line=1, row_oriented=true, compact_to_singleline=false)
    ws = isa(sheet, Symbol) ? xf[string(sheet)] : xf[sheet]
    sheet = ws.name
    # orientation handling
    ws = begin
            rg = XLSX.get_dimension(ws)
            if row_oriented
                rg = XLSX.CellRange(XLSX.CellRef(start_line, rg.start.column_number), rg.stop)
                dt = ws[rg]
            else
                rg = XLSX.CellRange(XLSX.CellRef(rg.start.row_number, start_line), rg.stop)
                dt = permutedims(ws[rg])
            end
            dt[broadcast(i -> !all(ismissing.(dt[i, :])), 1:size(dt, 1)),
               broadcast(j -> !ismissing(dt[1, j]), 1:size(dt, 2))]
        end

    if compact_to_singleline
        colnames = permutedims(ws[1, :])
        ws2 = broadcast(col -> [ws[2:end, col]], 1:size(ws, 2))
        ws = [colnames; hcat(ws2...)]
    end
    JSONWorksheet(ws, xf.filepath, sheet)
end
function JSONWorksheet(xlsxpath, sheet; args...)
    xf = XLSX.readxlsx(xlsxpath)
    x = JSONWorksheet(xf, sheet; args...)
    close(xf)
    return x
end
"""
    JSONWorkBook
Preserves XLSX WorkBook data structure
"""
mutable struct JSONWorkbook
    package::XLSX.XLSXFile
    sheets::Vector{JSONWorksheet}
    sheetindex::DataFrames.Index
end

function JSONWorkbook(xf::XLSX.XLSXFile, v::Vector{JSONWorksheet})
    index = DataFrames.Index(sheetnames.(v))
    JSONWorkbook(xf, v, index)
end
function JSONWorkbook(xlsxpath, sheets; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    JSONWorkbook(xf, sheets; kwargs...)
end
function JSONWorkbook(xlsxpath; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    JSONWorkbook(xf; kwargs...)
end
# same kwargs for all sheets
function JSONWorkbook(xf::XLSX.XLSXFile, sheets = XLSX.sheetnames(xf); kwargs...)
    v = Array{JSONWorksheet, 1}(undef, length(sheets))
    for (i, s) in enumerate(sheets)
        v[i] = JSONWorksheet(xf, s; kwargs...)
    end
    close(xf)

    JSONWorkbook(xf, v)
end
# Different Kwargs per sheet
function JSONWorkbook(xlsxpath::AbstractString, sheets, kwargs_per_sheet::Dict)
    xf = XLSX.readxlsx(xlsxpath)

    v = Array{JSONWorksheet, 1}(undef, length(sheets))
    for (i, s) in enumerate(sheets)
        v[i] = JSONWorksheet(xf, s; kwargs_per_sheet[s]...)
    end
    close(xf)

    JSONWorkbook(xf, v)
end
# fallback functions
hassheet(jwb::JSONWorkbook, s::Symbol) = haskey(jwb.sheetindex, s)
getsheet(jwb::JSONWorkbook, i) = jwb.sheets[i]
getsheet(jwb::JSONWorkbook, ind::Symbol) = getsheet(jwb, jwb.sheetindex[ind])
sheetnames(jwb::JSONWorkbook) = names(jwb.sheetindex)

xlsxpath(jwb::JSONWorkbook) = jwb.package.filepath

XLSX.isopen(jwb::JSONWorkbook) = isopen(jwb.package)
XLSX.close(jwb::JSONWorkbook) = close(jwb.package)

Base.length(jwb::JSONWorkbook) = length(jwb.sheets)
Base.lastindex(jwb::JSONWorkbook) = length(jwb.sheets)

Base.getindex(jwb::JSONWorkbook, i::Integer) = getsheet(jwb, i)
Base.getindex(jwb::JSONWorkbook, s::Symbol) = getsheet(jwb, s)
Base.getindex(jwb::JSONWorkbook, i::UnitRange) = getsheet(jwb, i)

Base.setindex!(jwb::JSONWorkbook, x, i1::Int) = setindex!(jwb.sheets, x, i1)

function Base.deleteat!(jwb::JSONWorkbook, i::Integer)
    deleteat!(getfield(jwb, :sheets), i)
    setfield!(jwb, :sheetindex, DataFrames.Index(sheetnames.(getfield(jwb, :sheets))))
    jwb
end
function Base.deleteat!(jwb::JSONWorkbook, sheet::Symbol)
    i = getfield(jwb, :sheetindex)[sheet]
    deleteat!(jwb, i)
end

Base.iterate(jwb::JSONWorkbook) = iterate(jwb, 1)
function Base.iterate(jwb::JSONWorkbook, st)
    st > length(jwb) && return nothing
    return (jwb[st], st + 1)
end

function Base.show(io::IO, jwb::JSONWorkbook)
    wb = jwb.package.workbook
    print(io, "XLSXFile(\"$(basename(jwb.package.filepath))\") ",
              "containing $(length(jwb)) Worksheets\n")
    @printf(io, "%6s %-15s\n", "index", "name")
    println(io, "-"^(6+1+15+1))

    for el in jwb.sheetindex.lookup
        name = string(el[1])
        @printf(io, "%6s %-15s\n", el[2], string(el[1]))
    end
end

# needs better name
function parse_special_dataframe(arr::Array{T}) where T
    missing_col = ismissing.(arr[1, :])
    arr = arr[:, broadcast(!, missing_col)]

    missing_row = broadcast(r -> all(ismissing.(arr[r, :])), 1:size(arr, 1))
    arr = arr[broadcast(!, missing_row), :]

    parse_special_dataframe(string.(arr[1, :]), arr[2:end, :])
end
function parse_special_dataframe(colnames, data)
    col_infos, d2 = assign_jsontype(colnames)

    # init DataFrame
    template = DataFrame()
    for el in d2
        k = Symbol(el[1])
        template[k] = if ismissing(el[2])
                    Any[el[2]]
            else
                    [el[2]]
            end
    end
    df = deepcopy(template)
    [append!(df, deepcopy(template)) for i in 2:size(data, 1)]

    # fill DataFrame
    for i in 1:size(data, 1), j in 1:size(data, 2)
        x = data[i, j]
        T2, colinfo =  col_infos[j]

        if T2 <: Dict
            df[i, Symbol(colinfo[1])][colinfo[2]] = x

        elseif T2 <: Array{Dict, 1}
            df[i, Symbol(colinfo[1])][colinfo[2]][colinfo[3]] = x

        elseif T2 <: Array{T3, 1} where T3
            if !ismissing(x) && !isa(x, Real)
                x = filter(!isempty, split(x, Regex(join(XLSXasJSON.DELIM, "|"))))
            end
            if T2 <: Array{T3, 1} where T3 <: Real
                if !ismissing(x)
                    x = broadcast(x -> (ismissing(x) || isa(x, Real)) ? x : parse.(eltype(T2), x), x)
                end
            end
            df[i, Symbol(colinfo)] = x
        else
            df[i, Symbol(colinfo)] = x
        end
    end
    return df
end

data(jws::JSONWorksheet) = getfield(jws, :data)
xlsxpath(jws::JSONWorksheet) = getfield(jws, :xlsxpath)
sheetnames(jws::JSONWorksheet) = getfield(jws, :sheetname)

## JSONWorksheet interface
DataFrames.index(jws::JSONWorksheet) = DataFrames.index(data(jws))
DataFrames.nrow(jws::JSONWorksheet) = nrow(data(jws))
DataFrames.ncol(jws::JSONWorksheet) = ncol(data(jws))

function Base.getindex(jws::JSONWorksheet, colinds::Any)
    return getindex(data(jws), colinds)
end
function Base.getindex(jws::JSONWorksheet, rowinds::Any, colinds::Any)
    return getindex(data(jws), rowinds, colinds)
end
function Base.setindex!(jws::JSONWorksheet, v, col_ind)
    setindex!(data(jws), v, col_ind)
end


function Base.sort(jws::JSONWorksheet, kwargs...)
    JSONWorksheet(sort(jws[:], kwargs...), xlsxpath(jws), sheetnames(jws))
end
function Base.sort!(jws::JSONWorksheet, kwargs...)
    setfield!(jws, :data, sort(jws[:], kwargs...))
end

function Base.show(io::IO, x::JSONWorksheet)
    @printf(io, "[%s] sheet_name:%s \n", basename(xlsxpath(x)), sheetnames(x))
    show(io, data(x))
end
# TODO: Need to change this fucntion to override only JSONWorksheet, not OrderedDict itself
# see base/show.jl:73l
function Base.show(io::IO, x::OrderedDict)
    for (i, (k, v)) in enumerate(x)
        print(io, "{", k, ": ")
        print(io, v, "}")
        i < length(x) && print(io, ", ")
    end
end
