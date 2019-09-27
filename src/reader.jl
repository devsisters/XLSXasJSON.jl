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
        # TODO: provide error messaqge for missing "." key[1,key2]
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
    jsonkeys = Array{Any}(undef, length(cnames))
    
    @inbounds for (i, key) in enumerate(cnames)
        key = string(key)
        jk = split(key, ".")
        # last key has Type info
        endkey, T = determine_datatype(jk[end])
        if isa(endkey, Array)
            jk = [jk[1:end-1]; endkey]
        else
            jk[end] = endkey
        end
        jsonkeys[i] = jk
        map[key] = (T, jk)
    end
    @assert allunique(jsonkeys) "Nested JSON keys must be unique, check for duplication within \n$jsonkeys"

    XLSXWrapperMeta(map)
end

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

@inline function prepare_merge(x::XLSXWrapperData)
    K = keytype(x) <: Integer ? Integer : AbstractString
    convert(OrderedDict{K, Any}, x)
end
@inline function prepare_merge(x::XLSXWrapperData{T2}) where T2<:XLSXWrapperData
    K = keytype(x) <: Integer ? Integer : AbstractString
    OrderedDict{K, Any}(Pair(x.key, prepare_merge(x.value)))
end


Base.iterate(x::XLSXWrapperData) = iterate(x, 1)
Base.iterate(x::XLSXWrapperData, i) = i > length(1) ? nothing : Pair(x.key, x.value)

Base.keytype(x::XLSXWrapperData) = typeof(x.key)
Base.valtype(x::XLSXWrapperData{T}) where T = T

recursive_merge(x::XLSXWrapperData) = convert(OrderedDict, x)
function recursive_merge(d::XLSXWrapperData, others::XLSXWrapperData...)
    merge(recursive_merge, 
        prepare_merge(d), 
        prepare_merge.(others)...)
end
#TODO: merge 없애고 recursive_merge 만으로 돌아가도록 override 할 것!
recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
recursive_merge(d::AbstractDict, x::AbstractDict...) = merge(recursive_merge, d, x...)

"""
    collect_vecdict!(x::T) where {T <: AbstractDict}

overwrites `Dict{K<:Integer,V} to Array{Dict, 1}` recursively
"""
collect_vecdict(x) = x
function collect_vecdict(x::T) where {T <: AbstractDict}
    @inbounds for k in keys(x)
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
    # sort by IntegerKey and dropmissing 
    sort!(x)
    r = collect(values(x))
    check_missing = Int[]
    @inbounds for (i, el) in enumerate(r)
        if all(ismissing.(values(el))) 
            push!(check_missing, i)
        end
    end
    deleteat!(r, check_missing)

    return r
end

#===================================================================================
 Interfaces

===================================================================================#

mutable struct JSONWorksheet
    xlsxpath::String
    meta::XLSXWrapperMeta
    data::Array{T, 1} where T <: AbstractDict
    sheetname::String
end
function JSONWorksheet(xlsxpath, arr::Array{T, 2}, sheet) where T
    arr = dropmissing(arr)
    @assert !isempty(arr) "$(xlsxpath)!$(sheet) does not contains any data, try change optional argument'start_line'"

    meta = XLSXWrapperMeta(arr[1, :])
    data = map(i -> construct_dict(meta, arr[i, :]), 2:size(arr, 1))
    data = collect_vecdict.(data)

    JSONWorksheet(xlsxpath, meta, data, string(sheet))
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
        end

    JSONWorksheet(xf.filepath, ws, sheet)
end
function JSONWorksheet(xlsxpath, sheet; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    x = JSONWorksheet(xf, sheet; kwargs...)
    close(xf)
    return x
end
@inline function dropmissing(arr::Array{T, 2}) where T
    cols = falses(size(arr, 2))
    @inbounds for c in 1:size(arr, 2)
        # There must be a column name, or it's a commet line
        if !ismissing(arr[1, c])
            for r in 1:size(arr, 1)
                if !ismissing(arr[r, c])
                    cols[c] = true
                    break
                end
            end
        end
    end

    arr = arr[:, cols]
    rows = falses(size(arr, 1))
    @inbounds for r in 1:size(arr, 1)
        for c in 1:size(arr, 2)                
            if !ismissing(arr[r, c])
                rows[r] = true
                break
            end
        end
    end
    return arr[rows, :]
end

@inline function construct_dict(meta::XLSXWrapperMeta, singlerow)
    result = Array{XLSXWrapperData, 1}(undef, length(meta))
    for (i, el) in enumerate(meta)
        T, steps = el[2]
        value = singlerow[i]
        if T <: Array{T2, 1} where T2
            if !ismissing(value)
                if isa(value, AbstractString)
                    x = filter(!isempty, split(value, Regex(join(DELIM, "|"))))
                    value = strip.(x) #NOTE dangerous?
                    if T <: Array{T3, 1} where T3 <: Real
                        value = parse.(eltype(T), value)
                    end
                else
                    if T <: Array{T3, 1} where T3 <: AbstractString
                        value = [string(value)]
                    else
                        value = [value]
                    end
                end
            end
        end
        
        x = XLSXWrapperData(steps[end], value)
        if length(steps) > 1
            @inbounds for k in reverse(steps[1:end-1])
                x = XLSXWrapperData(k, x)
            end
        end
        result[i] = x
    end
    return recursive_merge(result...)
end

data(jws::JSONWorksheet) = getfield(jws, :data)
xlsxpath(jws::JSONWorksheet) = getfield(jws, :xlsxpath)
sheetnames(jws::JSONWorksheet) = getfield(jws, :sheetname)

Base.iterate(jws::JSONWorksheet) = iterate(data(jws))
Base.iterate(jws::JSONWorksheet, i) = iterate(data(jws), i)

Base.size(jws::JSONWorksheet) = (length(jws.data), length(jws.meta))
function Base.size(jws::JSONWorksheet, d)
    d == 1 ? length(jws.data) : 
    d == 2 ? length(jws.meta) : throw(DimensionMismatch("only 2 dimensions of `JSONWorksheets` object are measurable"))
end
Base.length(jws::JSONWorksheet) = length(data(jws))
Base.getindex(jws::JSONWorksheet, i) = getindex(data(jws), i)
Base.getindex(jws::JSONWorksheet, i1::Int, i2::Int, I::Int...) = getindex(data(jws), i1, i2, I...)
Base.lastindex(jws::JSONWorksheet) = lastindex(data(jws))


function Base.merge(a::JSONWorksheet, b::JSONWorksheet, bykey::AbstractString)
    @assert haskey(a.meta, bykey) "JSONWorksheet-$(a.sheetname) do not has `$bykey`"
    @assert haskey(b.meta, bykey) "JSONWorksheet-$(b.sheetname) do not has `$bykey`"
    
    output = a.data
    for row in output
        k = row[bykey]
        sender = filter(el -> el[bykey] == k, b.data)
        if !isempty(sender)
            @assert length(sender) == 1 "JSONWorksheet-$(b.sheetname) has more than 1 row of `$bykey`"

            merge!(row, sender[1])
        end
    end

    if length(unique([keys(a.meta)... keys(b.meta)...])) > length(keys(a.meta)) + length(keys(b.meta)) - 1
        @warn "There are duplicated key within sheets, data in '$(a.sheetname)' will be overwritten by '$(b.sheetname)'"
    end
    meta = merge(a.meta, b.meta)

    JSONWorksheet(a.xlsxpath, meta, output, a.sheetname)
end
function Base.append!(a::JSONWorksheet, b::JSONWorksheet)
    @assert keys(a.meta) == keys(b.meta) "Column names must be same for append!\n $(setdiff(keys(a.meta), keys(b.meta)))"

    append!(a.data, b.data)
end

# TODO 임시 함수임... 더 robust 하게 수정필요
function Base.sort!(jws::JSONWorksheet, key; kwargs...)
    sorted_idx = sortperm(map(el -> el[key], data(jws)); kwargs...)
    jws.data = data(jws)[sorted_idx]
end


"""
    JSONWorkBook
Preserves XLSX WorkBook data structure
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
hassheet(jwb::JSONWorkbook, s::Symbol) = haskey(jwb.sheetindex, s)
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
    # TODO deprecate df
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

    index = sort(jwb.sheetindex.lookup; byvalue = true)
    for el in index
        name = string(el[1])
        @printf(io, "%6s %-15s\n", el[2], string(el[1]))
    end
end
function Base.summary(io::IO, jws::JSONWorksheet)
    @printf("%d×%d %s - %s!%s\n", size(jws)..., "JSONWorksheet", 
        basename(xlsxpath(jws)), sheetnames(jws))
end
function Base.show(io::IO, jws::JSONWorksheet)
    summary(io, jws)
    #TODO truncate based on screen size
    x = data(jws)
    print(io, "row 1 => ")
    print(io, JSON.json(x[1], 1))
    if length(x) > 1
        print("...")
        print(io, "row $(length(x)) => ")
        print(io, JSON.json(x[end]))
    end
end
