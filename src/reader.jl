"""
    Able to use other string as delimiter by changing values of `DELIM`
push!(XLSXasJSON.DELIM, ",")
"""
const DELIM = [";"]

const VEC_REGEX = r"\((.*?)\)" # key(), key(T)
const VECDICT_REGEX = r"\[(.*?)\]" # [idx,key]
function determine_datatype(k)::Tuple
    # [idx,key]
    TV = Any
    if occursin(VECDICT_REGEX, k)
        k = chop(k; head=1, tail=1) #remove []
        k = split(k, ",")
        @assert length(k) == 2 "Specify index of Vector{Dict} data in $(k)"

        if occursin(VEC_REGEX, k[2])
            TV = finddatatype_in_vector(k[2])
            k[2] = replace(k[2], VEC_REGEX => "")
        end
        k = [parse(Int, k[1]), k[2]]

    # key(), key(T)
    elseif occursin(VEC_REGEX, k)
        TV = finddatatype_in_vector(k)
        k = replace(k, VEC_REGEX => "")
    end
    (k ,TV)
end
function finddatatype_in_vector(k)
    m = match(VEC_REGEX, k)
    t = uppercasefirst(m.captures[1])
    if t == ""
        Vector{Any}
    elseif t == "Float"
        Vector{Float64}
    else
        @eval Vector{$(Symbol(t))}
    end
end

"""
    XLSXWrapperMeta

cnames - 엑셀의 컬럼명
map - 각 컬럼명을 연속된 Key와 Idx로 만들어 저장된다
      Key일 경우 Dict
      Idx일 경우 Vector에서 위치를 나타낸다

"""
struct XLSXWrapperMeta{K,V} <: AbstractDict{K,V}
    map::AbstractDict{K,V}
end
function XLSXWrapperMeta(cnames)
    @assert allunique(cnames) "Column names must be unique, check for duplication in \n$cnames"

    map = OrderedDict{String, Any}()
    for k in cnames
        name = split(k, ".")
        # last key has Type info
        nameend, T = determine_datatype(name[end])
        if isa(nameend, Array)
            name = [name[1:end-1]; nameend]
        else
            name[end] = nameend
        end
        map[k] = (T, name)
    end

    XLSXWrapperMeta(map)
end
# NOTE:: revise용 임시!!!
XLSXWrapperMeta(x::XLSXWrapperMeta) = XLSXWrapperMeta(x.cnames)

#fallback functions
Base.iterate(x::XLSXWrapperMeta) = iterate(x.map)
Base.iterate(x::XLSXWrapperMeta, i::Int) = iterate(x.map, i)
Base.length(x::XLSXWrapperMeta) = length(x.map)

Base.get(x::XLSXWrapperMeta, key, default) = get(x.map, key, default)
Base.filter(f, x::XLSXWrapperMeta) = filter(f, x.map)
function Base.merge(a::XLSXWrapperMeta, b::XLSXWrapperMeta)
    cnames = [collect(keys(a.map)); collect(keys(b.map))]
    XLSXWrapperMeta(unique(cnames))
end

mutable struct XLSXWrapperData{T}
    key::Union{AbstractString, Integer}
    value::T
end
function Base.convert(::Type{T}, x::XLSXWrapperData{T2}) where {T<:AbstractDict, T2} 
    T(Pair(x.key, x.value))
end
function Base.convert(::Type{T}, x::XLSXWrapperData{T2}) where {T<:AbstractDict, T2<:XLSXWrapperData} 
    T(Pair(x.key, convert(T, x.value)))
end

function recursive_merge(XLSXWrapperData...)
    recursive_merge(convert.(OrderedDict, XLSXWrapperData...)...)
end
recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)

"""
    collect_vecdict!(x::T) where {T <: AbstractDict}

overwrites `Dict{K<:Integer,V} to Array{Dict, 1}` recursively
"""
collect_vecdict(x) = x
function collect_vecdict(x::T) where {T <: AbstractDict}
    for k in keys(x)
        v = collect_vecdict(x[k])
        if isa(v, Array{T2, 1} where T2)
            # TODO T2 = @eval $(Symbol(T.name))
            nd = OrderedDict(Pair(k, collect_vecdict(x[k])))
            x = merge(x, nd)
        else
            x[k] = v
        end
    end
    return x
end

function collect_vecdict(x::AbstractDict{K,V}) where {K <: Integer, V}
    # remove Integer Key and filter missing
    r = collect(values(x))
    check_missing = Int[]
    for (i, el) in enumerate(r)
        if all(ismissing.(values(el)))
            push!(check_missing, i)
        end
    end
    deleteat!(r, check_missing)

    return r
end

################################################
# Interfaces

################################################

mutable struct JSONWorksheet
    meta
    data
    dataframe::Union{DataFrame, Missing} # for datahandling like Excel spreadsheet
    xlsxpath::String
    sheetname::String
end
function JSONWorksheet(arr::Array{T}, xlsxpath, sheet, create_dataframe = false) where T
    missing_col = ismissing.(arr[1, :])
    arr = arr[:, broadcast(!, missing_col)]

    missing_row = broadcast(r -> all(ismissing.(arr[r, :])), 1:size(arr, 1))
    arr = arr[broadcast(!, missing_row), :]

    meta = XLSXWrapperMeta(string.(arr[1, :]))
    data = broadcast(i -> construct_dict(meta, arr[i, :]), 2:size(arr, 1))
    data = collect_vecdict.(data)

    if create_dataframe
        dataframe = construct_dataframe(data) 
    else
        dataframe = missing
    end    
    JSONWorksheet(meta, data, dataframe, xlsxpath, string(sheet))
end
function JSONWorksheet(xf::XLSX.XLSXFile, sheet;
                       start_line=1, row_oriented=true)
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
    @assert !isempty(ws) "$(sheet)!$start_line:$start_line does not contains any data, try change 'start_line=$start_line'"

    JSONWorksheet(ws, xf.filepath, sheet)
end
function JSONWorksheet(xlsxpath, sheet; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    x = JSONWorksheet(xf, sheet; kwargs...)
    close(xf)
    return x
end


function construct_dict(meta::XLSXWrapperMeta, singlerow)
    result = Array{XLSXWrapperData, 1}(undef, length(meta))
    for (i, el) in enumerate(meta)
        T, steps = el[2]
        value = singlerow[i]
        if T <: Array{T2, 1} where T2
            if !ismissing(value)
                x = filter(!isempty, split(value, Regex(join(DELIM, "|"))))
                value = strip.(x) #NOTE dangerous?
                if T <: Array{T3, 1} where T3 <: Real
                    value = parse.(eltype(T), value)
                end
            end
        end
        
        x = XLSXWrapperData(steps[end], value)
        if length(steps) > 1
            for k in reverse(steps[1:end-1])
                x = XLSXWrapperData(k, x)
            end
        end
        result[i] = x
    end
    return recursive_merge(result)
end
function construct_dataframe(data)
    k = unique(keys.(data))
    @assert length(k) == 1 "something is wrong at $k"
    v = Array{Any, 1}(undef, length(k[1]))
    for (i, key) in enumerate(k[1])
        v[i] = getindex.(data, key)
    end

    return DataFrame(v, Symbol.(k[1]))
end
function construct_dataframe!(jws::JSONWorksheet)
    jws.dataframe = construct_dataframe(jws.data)
end

data(jws::JSONWorksheet) = getfield(jws, :data)
df(jws::JSONWorksheet) = getfield(jws, :dataframe)

xlsxpath(jws::JSONWorksheet) = getfield(jws, :xlsxpath)
sheetnames(jws::JSONWorksheet) = getfield(jws, :sheetname)

function Base.merge(a::JSONWorksheet, b::JSONWorksheet, bykey)
    @assert haskey(a.meta, bykey) "JSONWorksheet-$(a.sheetname) do not has `$bykey`"
    @assert haskey(b.meta, bykey) "JSONWorksheet-$(b.sheetname) do not has `$bykey`"
    
    output = a.data
    for row in output
        k = row[bykey]
        sender = filter(el -> el[bykey] == k, b.data)
        @assert length(sender) == 1 "JSONWorksheet-$(b.sheetname) has more than 1 row of `$bykey`"

        merge!(row, sender[1])
    end
    meta = merge(a.meta, b.meta)
    JSONWorksheet(meta, output, missing, a.xlsxpath, a.sheetname)
end

# TODO 임시 함수임... 더 robust 하게 수정필요
function Base.sort!(jws::JSONWorksheet, key; kwargs...)
    sorted_idx = sortperm(broadcast(el -> el[key], data(jws)); kwargs...)
    jws.data = data(jws)[sorted_idx]
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
    wsnames = Symbol.(sheetnames.(v))
    index = DataFrames.Index(wsnames)
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
function construct_dataframe!(jwb::JSONWorkbook) 
    for i in 1:length(jwb) 
        construct_dataframe!(jwb[i])
    end
end
# JSONWorkbook fallback functions
hassheet(jwb::JSONWorkbook, s::Symbol) = haskey(jwb.sheetindex, s)
getsheet(jwb::JSONWorkbook, i) = jwb.sheets[i]
getsheet(jwb::JSONWorkbook, s::Symbol) = getsheet(jwb, jwb.sheetindex[s])
sheetnames(jwb::JSONWorkbook) = names(jwb.sheetindex)

xlsxpath(jwb::JSONWorkbook) = jwb.package.filepath

XLSX.isopen(jwb::JSONWorkbook) = isopen(jwb.package)
XLSX.close(jwb::JSONWorkbook) = close(jwb.package)

Base.length(jwb::JSONWorkbook) = length(jwb.sheets)
Base.lastindex(jwb::JSONWorkbook) = length(jwb.sheets)

Base.getindex(jwb::JSONWorkbook, i::Integer) = getsheet(jwb, i)
Base.getindex(jwb::JSONWorkbook, s::Symbol) = getsheet(jwb, s)
Base.getindex(jwb::JSONWorkbook, i::UnitRange) = getsheet(jwb, i)

Base.setindex!(jwb::JSONWorkbook, jws::JSONWorksheet, i1::Int) = setindex!(jwb.sheets, jws, i1)
Base.setindex!(jwb::JSONWorkbook, jws::JSONWorksheet, s::Symbol) = setindex!(jwb.sheets, jws, jwb.sheetindex[s])


# TODO: need to make it more cleaner!
function Base.setindex!(jwb::JSONWorkbook, df::DataFrame, i1::Int)
    new_jws = JSONWorksheet(df, xlsxpath(jwb), sheetnames(jwb)[i1])
    setindex!(jwb, new_jws, i1)
end
function Base.setindex!(jwb::JSONWorkbook, df::DataFrame, s::Symbol)
    new_jws = JSONWorksheet(df, xlsxpath(jwb), s)
    setindex!(jwb, new_jws, s)
end
function Base.deleteat!(jwb::JSONWorkbook, i::Integer)
    deleteat!(getfield(jwb, :sheets), i)
    s = Symbol.(sheetnames.(getfield(jwb, :sheets)))
    setfield!(jwb, :sheetindex, DataFrames.Index(s))
    jwb
end
function Base.deleteat!(jwb::JSONWorkbook, sheet::Symbol)
    i = getfield(jwb, :sheetindex)[sheet]
    deleteat!(jwb, i)
end

Base.iterate(jwb::JSONWorkbook) = iterate(jwb, 1)
function Base.iterate(jwb::JSONWorkbook, st)
    st > length(jwb) && return nothing
    return (df(jwb[st]), st + 1)
end

## Display
function Base.summary(io::IO, jwb::JSONWorkbook)
    @printf(io, "JSONWorkbook(\"%s\") containing %i Worksheets\n",
                basename(xlsxpath(jwb)), length(jwb))
end
function Base.show(io::IO, jwb::JSONWorkbook)
    wb = jwb.package.workbook
    summary(io, jwb)
    @printf(io, "%6s %-15s\n", "index", "name")
    println(io, "-"^(6+1+15+1))

    for el in jwb.sheetindex.lookup
        name = string(el[1])
        @printf(io, "%6s %-15s\n", el[2], string(el[1]))
    end
end
function Base.summary(jws::JSONWorksheet)
    @sprintf("%d×%d %s - %s!%s", size(jws)..., "JSONWorksheet", basename(xlsxpath(jws)), sheetnames(jws))
end
function Base.show(io::IO, jws::JSONWorksheet)
    summary(io, jws)
    show(io, df(jws))
end
# TODO: Need to change this fucntion to override only JSONWorksheet, not OrderedDict itself
# see base/show.jl:73l
# function Base.show(io::IO, x::OrderedDict)
#     for (i, (k, v)) in enumerate(x)
#         print(io, "{", k, ": ")
#         print(io, v, "}")
#         i < length(x) && print(io, ", ")
#     end
# end