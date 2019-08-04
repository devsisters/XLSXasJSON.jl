using Test
using XLSXasJSON
using JSON
using XLSX
using DataFrames, DataStructures

row_oriented = true

using Pkg

f = joinpath(@__DIR__, "../data/refactoring.xlsx")
xf = XLSX.readxlsx(f)


ws = xf["simple"]
ws = begin
        rg = XLSX.get_dimension(ws)
        if row_oriented
            rg = XLSX.CellRange(XLSX.CellRef(1, rg.start.column_number), rg.stop)
            dt = ws[rg]
        end
        dt[broadcast(i -> !all(ismissing.(dt[i, :])), 1:size(dt, 1)),
           broadcast(j -> !ismissing(dt[1, j]), 1:size(dt, 2))]
    end




# 컬럼명 파싱
function parse_jsonstructure(x::AbstractString)
    reg = r"\.\[(.*?)\]" # .[*]
    if occursin(reg, x)
        vectors = match(reg, x)
        @assert length(vectors.captures) == 1 "Can't handle more than one Vector{Dict}"
        p = replace(x, vectors.match => "")
        c = chop(vectors.match; head = 2, tail = 1)
        parse_jsonstructure(p, c)
    else
        x2 = split(x, ".")

        v = Array{Any}(undef, length(x2))
        for i in reverse(eachindex(x2))
            k = x2[i]
            v[i] = (i == length(x2) ? (k) : [k, v[i+1]])
        end
        return v[1]
    end
end
function parse_jsonstructure(p, child)
    x2 = split(p, ".")

    v = Array{Any}(undef, length(x2))
    for i in reverse(eachindex(x2))
        k = x2[i]
        v[i] = i == length(x2) ? (k, [parse_jsonstructure(child)]) : [k, v[i+1]]
    end
    return v[1]
end

function construct_jsondict(x::Array{Array{SubString{String},1},1})
    construct_jsondict(x[1])
end
function construct_jsondict(x::AbstractArray)
    v = Array{Any}(undef, length(x))
    for i in reverse(eachindex(x))
        el = x[i]
        v[i] = begin
            if i == length(x)
                if isa(el, Tuple) || isa(el, AbstractArray)
                    OrderedDict(string(el[1]) => [construct_jsondict(el[2])])
                else
                    OrderedDict(string(el) => missing)
                end
            else
                OrderedDict(string(el) => v[i+1])
            end
        end
    end
    return v[1]
end

a = ["step1.step2.[step3.step4]" "step1.step2.[step3-2]";
     "this" 2]

colnames =  a[1, :]
datas = a[2:end, :]


comp = JSON.parsefile(joinpath(@__DIR__, "../data/dicts.json"); dicttype = OrderedDict)
comp = comp[1]


col = 1
d = OrderedDict{String, Any}()

for col in 1:2

    colname = parse_jsonstructure(a[1, col])
    if col == 1
        d = construct_jsondict(colname)
    end
    assign_data!(d, colname, 1)

end

function assign_data!(d::AbstractDict, col_name, col_ind, data)
    ref = d
    complete = true
    while complete
        for (i, el) in enumerate(col_name)
            @show ref
            if isa(el, AbstractString)
                ref = getindex(ref, el)
            elseif isa(el, Tuple)
                ref = getindex(ref, el[1])
                complete = false
            end
        end
    end
    ref
end

function _getindex(d::AbstractDict, x::AbstractString)
    getindex(d, x)
end
function _getindex(d::AbstractDict, x::Tuple)
    getindex(_getindex(d, x[1]), x[2])
end

col = parse_jsonstructure.(colnames)

d = OrderedDict()
v = Any[]
for el in col

    for x in el

        d[foo(x)] = 0
    end

end


b = ["step1()" "step1-2.step2[]" "step1-3.[step2.step3()]" "step1-3.[step2.step3-2]";
     "1;2;3;4;5" "6;7;8;9;10" "11;12;13;14;15" "this"]



struct Foo
    depth::Int
    keys
    value
end
