"""
    JSONWorksheet
"""
mutable struct JSONWorksheet
    xlsxpath::String
    pointer::Array{JSONPointer, 1}
    data::Array{T, 1} where T 
    sheetname::String
end
function JSONWorksheet(xlsxpath, arr::Array{T, 2}, sheet, delim) where T
    arr = dropemptyrange(arr)
    @assert !isempty(arr) "'$(xlsxpath)!$(sheet)' don't have valid column names, try change optional argument'start_line'"

    p = map(el -> begin 
                    startswith(el, TOKEN_PREFIX) ? 
                        JSONPointer(el) : JSONPointer(TOKEN_PREFIX * el) 
                end, arr[1, :])
    real_keys = map(el -> el.token, p)
    if !allunique(real_keys) 
        throw(AssertionError("column names must be unique, check for duplication $(arr[1, :])"))
    end

    template = create_by_pointer(OrderedDict, p)
    data = Array{typeof(template), 1}(undef, size(arr, 1)-1)
    for i in 1:length(data)
        v = deepcopy(template)
        data[i] = v
        row = arr[i+1, :]
        @inbounds for (col, p) in enumerate(p)
            v[p] = collect_cell(p, row[col], delim)
        end
    end

    JSONWorksheet(normpath(xlsxpath), p, data, string(sheet))
end
function JSONWorksheet(xf::XLSX.XLSXFile, sheet;
                       start_line = 1, 
                       row_oriented = true, 
                       delim = ";")
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

    JSONWorksheet(xf.filepath, ws, sheet, delim)
end
function JSONWorksheet(xlsxpath, sheet; kwargs...)
    xf = XLSX.readxlsx(xlsxpath)
    x = JSONWorksheet(xf, sheet; kwargs...)
    close(xf)
    return x
end
@inline function dropemptyrange(arr::Array{T, 2}) where T
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

function collect_cell(p::JSONPointer{T}, cell, delim) where T
    if ismissing(cell) 
        val = null_value(p)
    else
        if T <: AbstractArray
            if isa(cell, AbstractString)
                val = split(cell, delim)
                isempty(val[end]) && pop!(val)
                if eltype(T) <: Real 
                    val = parse.(eltype(T), val)
                elseif eltype(T) <: AbstractString 
                    val = string.(val)
                end
            else 
                val = cell
                if eltype(T) <: Real
                    if isa(cell, AbstractString) 
                        val = parse(eltype(T), cell)
                    end
                elseif eltype(T) <: AbstractString
                    if !isa(cell, AbstractString)
                        val = string(cell)
                    end
                end
                val = convert(T, [val])
            end
        else 
            val = cell
        end
    end
    return val
end

data(jws::JSONWorksheet) = getfield(jws, :data)
xlsxpath(jws::JSONWorksheet) = getfield(jws, :xlsxpath)
sheetnames(jws::JSONWorksheet) = getfield(jws, :sheetname)
Base.keys(jws::JSONWorksheet) = jws.pointer

Base.iterate(jws::JSONWorksheet) = iterate(data(jws))
Base.iterate(jws::JSONWorksheet, i) = iterate(data(jws), i)

Base.size(jws::JSONWorksheet) = (length(jws.data), length(jws.pointer))
function Base.size(jws::JSONWorksheet, d)
    d == 1 ? length(jws.data) : 
    d == 2 ? length(jws.pointer) : throw(DimensionMismatch("only 2 dimensions of `JSONWorksheets` object are measurable"))
end
Base.length(jws::JSONWorksheet) = length(data(jws))

##############################################################################
##
## getindex() definitions
##
##############################################################################
Base.getindex(jws::JSONWorksheet, i) = getindex(jws[:], i)
Base.getindex(jws::JSONWorksheet, ::Colon) = jws.data[:]

Base.firstindex(jws::JSONWorksheet) = 1
Base.lastindex(jws::JSONWorksheet) = lastindex(data(jws))

@inline function Base.getindex(jws::JSONWorksheet, row_ind::Integer, col_ind::Integer)
    p = keys(jws)[col_ind]

    jws(row_ind, p)
end

function Base.getindex(jws::JSONWorksheet, row_ind::Integer, col_ind::JSONPointer)
    row = jws[row_ind]
    
    return row[col_ind]
end

@inline function Base.getindex(jws::JSONWorksheet, row_inds, col_ind::Integer)
    rows = jws[row_inds]
    p = keys(jws)[col_ind]

    map(row -> row[p], rows)
end



"""
    merge(a::JSONWorksheet, b::JSONWorksheet, bykey::AbstractString)

Construct a merged JSONWorksheet from the given JSONWorksheets.
If the same JSONPointer is present in another collection, the value for that key will be the      
value it has in the last collection listed.
"""
function Base.merge(a::JSONWorksheet, b::JSONWorksheet, bykey::AbstractString)
    key = JSONPointer(bykey)
    
    @assert in(key, a.pointer) "JSONWorksheet-$(a.sheetname) do not has `$key`"
    @assert in(key, b.pointer) "JSONWorksheet-$(b.sheetname) do not has `$key`"
    
    pointers = unique([a.pointer; b.pointer])

    keyvalues_a = map(el -> el[key], a.data)
    keyvalues_b = map(el -> el[key], b.data)
    ind = indexin(keyvalues_b, keyvalues_a)

    data = deepcopy(a.data)
    for (i, _b) in enumerate(b.data)
        j = ind[i]
        if isnothing(j)
            _a = deepcopy(_b)
            for p in a.pointer 
                _a[p] = null_value(p)
            end 
            push!(data, _a) 
        else 
            _a = data[j]
        end
        for p in b.pointer 
            _a[p] = _b[p]
        end
    end
    JSONWorksheet(a.xlsxpath, pointers, data, a.sheetname)
end
function Base.append!(a::JSONWorksheet, b::JSONWorksheet)
    ak = map(el -> el.token, keys(a)) 
    bk = map(el -> el.token, keys(b))
    
    if sort(ak) != sort(bk)
        throw(AssertionError("""Column names must be same for append!
         $(setdiff(collect(ak), collect(bk)))"""))
    end

    append!(a.data, b.data)
end

function Base.sort!(jws::JSONWorksheet, bykey; kwargs...)
    key = JSONPointer(bykey)
    sorted_idx = sortperm(map(el -> el[key], data(jws)); kwargs...)
    jws.data = data(jws)[sorted_idx]
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