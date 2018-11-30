"""
    JSONWorkSheet

**Constructors**

```julia
DataFrame(xlsxpath::String, sheet, jsonpath=nothing;)
```

**Arguments**

* `row_oriented` : true면 행으로 된 데이터, false면 열로 된 데이터
* `start_line` : n번째 행부터 읽어온다.
* `compact_to_singleline` : 모든 행을 첫줄에 Vector로 넣는다.
데이터는 반드시 직사각형이어야 한다.

"""
mutable struct JSONWorksheet <: AbstractDataFrame
    data::DataFrame
    xlsxpath::AbstractString
    jsonpath::AbstractString
    sheetname::Symbol
end

function JSONWorksheet(data::DataFrame, xlsxpath, sheet, jsonpath)
    if isa(jsonpath, Nothing)
        jsonpath = replace(basename(xlsxpath), r"\.[^.]*" => "_$sheet.json")
    end
    JSONWorksheet(data, xlsxpath, jsonpath, Symbol(sheet))
end
function JSONWorksheet(arr::Array{T, 2}, xlsxpath, sheet, jsonpath) where T
    data = parse_special_dataframe(arr)
    JSONWorksheet(data, xlsxpath, sheet, jsonpath)
end
function JSONWorksheet(xf::XLSX.XLSXFile, sheet, jsonpath;
                       row_oriented = true, start_line = 1, compact_to_singleline = false)
    ws = isa(sheet, Symbol) ? xf[string(sheet)] : xf[sheet]
    sheet = ws.name
    # orientation 고려하여 범위내의 데이터 불러오기
    ws = begin
            rg = XLSX.get_dimension(ws)
            if row_oriented
                rg = XLSX.CellRange(XLSX.CellRef(start_line, rg.start.column_number), rg.stop)
                dt = ws[rg]
            else
                rg = XLSX.CellRange(XLSX.CellRef(rg.start.row_number, start_line), rg.stop)
                dt = permutedims(ws[rg])
            end
            # missing row, col 제거
            dt[broadcast(i -> !all(ismissing.(dt[i, :])), 1:size(dt, 1)),
               broadcast(j -> !all(ismissing.(dt[:, j])), 1:size(dt, 2))]
        end
    if compact_to_singleline
        colnames = permutedims(ws[1, :])
        ws2 = broadcast(col -> [ws[2:end, col]], 1:size(ws, 2))
        ws = [colnames; hcat(ws2...)]
    end
    JSONWorksheet(ws, xf.filepath, sheet, jsonpath)
end
function JSONWorksheet(xlsxpath, sheet, jsonpath = nothing; args...)
    xf = XLSX.readxlsx(xlsxpath)
    x = JSONWorksheet(xf, sheet, jsonpath; args...)
    close(xf)
    return x
end
"""
    JSONWorkBook
JSON <-> XLSX 변환을 위한 데이터 타입
"""
mutable struct JSONWorkbook
    package::XLSX.XLSXFile
    sheets::Vector{JSONWorksheet}
    sheetindex::DataFrames.Index
end
function JSONWorkbook(xlsxpath, sheets; args...)
    xf = XLSX.readxlsx(xlsxpath)
    v = JSONWorksheet[]
    for s in sheets
        push!(v, JSONWorksheet(xf, s; args...))
    end
    close(xf)
    # index id가 엑셀파일과 다르게 생성됨
    index = DataFrames.Index(sheetnames.(v))
    JSONWorkbook(xf, v, index)
end
# 여러 시트를 합쳐서 하나의 워크북 구성
function JSONWorkbook(sheets::Vector{JSONWorksheet})
    xl = unique(xlsxpath.(sheet))
    if length(xl) != 1
        error("같은 파일만 워크북 생성 가능")
    end
    index = DataFrames.Index(sheet.(v))
    JSONWorkbook(xl[1], sheets, index)
end
# fallback functions
XLSX.isopen(jwb::JSONWorkbook) = isopen(jwb.package)
XLSX.close(jwb::JSONWorkbook) = close(jwb.package)

Base.length(jwb::JSONWorkbook) = length(jwb.sheets)

hassheet(jwb::JSONWorkbook, s::Symbol) = haskey(jwb.sheetindex, s)
getsheet(jwb::JSONWorkbook, i) = jwb.sheets[i]
getsheet(jwb::JSONWorkbook, ind::Symbol) = getsheet(jwb, jwb.sheetindex[ind])
sheetnames(jwb::JSONWorkbook) = names(jwb.sheetindex)

xlsxpath(jwb::JSONWorkbook) = jwb.package.filepath

Base.getindex(jwb::JSONWorkbook, i::Integer) = getsheet(jwb, i)
Base.getindex(jwb::JSONWorkbook, s::Symbol) = getsheet(jwb, s)


Base.iterate(jwb::JSONWorkbook) = iterate(jwb, 1)
function Base.iterate(jwb::JSONWorkbook, st)
    st > length(jwb) && return nothing
    return (jwb[st], st + 1)
end

function Base.show(io::IO, jwb::JSONWorkbook)
    wb = jwb.package.workbook
    print(io, "XLSXFile(\"$(basename(jwb.package.filepath))\") ",
              "containing $(XLSX.sheetcount(wb)) Worksheets\n")
    @printf(io, "%6s %-15s\n", "index", "name")
    println(io, "-"^(6+1+15+1))

    for el in jwb.sheetindex.lookup
        name = string(el[1])
        @printf(io, "%6s %-15s\n", el[2], string(el[1]))
    end
end


"""
    TODO: JSONColumnType 별로 함수 분리?
"""
function parse_special_dataframe(arr::Array{T, 2}) where T
    parse_special_dataframe(string.(arr[1, :]), arr[2:end, :])
end
function parse_special_dataframe(cols, data)
    df = DataFrame()
    for (i, x) in enumerate(cols)
        (T, key) = parse_keyname(x)
        if T <: Dict
            k = Symbol.(key)
            if !haskey(df, k[1])
                df[k[1]] = map(x -> OrderedDict(), 1:size(data, 1))
            end
            map(row -> df[row, k[1]][k[2]] = data[row, i], 1:size(data, 1))
        elseif T <: Array{Dict, 1}
            k = Symbol(split(key[1], "[")[1])
            if !haskey(df, k)
                df[k] = map(x -> [OrderedDict()], 1:size(data, 1))
            end

            idx = match(r"\[(\d+)\]", key[1]) |> x -> parse(UInt8, x.captures[1])
            k2 = Symbol(key[2])
            for row in 1:size(data, 1)
                if !ismissing(data[row, i])
                    _v = df[row, k]
                    if length(_v) < idx +1
                        push!(_v, OrderedDict())
                    end
                    _v[end][k2] = data[row, i]
                end
            end

        elseif T <: Array{T, 1} where T
            x = broadcast(x -> (ismissing(x) || isa(x, Real)) ? x :
                               filter(!isempty, split(x, ";")), data[:, i])
            if T <: Array{T, 1} where T <: Real
                if !ismissing(x)
                    x = broadcast(x -> (ismissing(x) || isa(x, Real)) ? x :
                                        parse.(eltype(T), x), x)
                end
            end
            df[Symbol(key)] = x
        else
            df[Symbol(key)] = data[:, i]
        end
    end
    return df
end

# AbstractDataFrame은 getproperty를 override하기 때문에 '.'으로 접근이 불가
data(jws::JSONWorksheet) = getfield(jws, :data)
xlsxpath(jws::JSONWorksheet) = getfield(jws, :xlsxpath)
jsonpath(jws::JSONWorksheet) = getfield(jws, :jsonpath)
sheetnames(jws::JSONWorksheet) = getfield(jws, :sheetname)

##############################################################################
##
## JSONWorksheet interface
##
##############################################################################
DataFrames.index(jws::JSONWorksheet) = DataFrames.index(data(jws))

DataFrames.nrow(jws::JSONWorksheet) = nrow(data(jws))
DataFrames.ncol(jws::JSONWorksheet) = ncol(data(jws))

function Base.getindex(jws::JSONWorksheet, colinds::Any)
    return getindex(data(jws), colinds)
end
function Base.getindex(jws::JSONWorksheet, rowinds::Any, colinds::Any)
    return getindex(data(jws), rowinds, colinds)
end

function Base.show(io::IO, x::JSONWorksheet)
    @printf(io, "[%s] sheet_name:%s \n", basename(xlsxpath(x)), sheetnames(x))
    show(io, data(x))
end
# OrderedDict 덮어씌웠는데 Dict랑 표현법이 아예 다른데 괜찮을지??
# TODO: base/show.jl:73l 참조하여 수정
function Base.show(io::IO, x::OrderedDict)
    for (i, (k, v)) in enumerate(x)
        print(io, "{", k, ": ")
        print(io, v, "}")
        i < length(x) && print(io, ", ")
    end
end
