using Test
using XLSXasJSON
using DataStructures
using JSON

data_path = joinpath(@__DIR__, "data")

@testset "JSONPointer Basic" begin

    a = XLSXasJSON.JSONPointer("/a/1/c")
    b = XLSXasJSON.JSONPointer("/a/5")   
    c = XLSXasJSON.JSONPointer("/a/2/d::Vector")
    d = XLSXasJSON.JSONPointer("/a/2/e::Vector{Int}")
    e = XLSXasJSON.JSONPointer("/a/2/f::Vector{Float64}")
    
    @test a.token == ("a", 1, "c")
    @test b.token == ("a", 5)
    @test c.token == ("a", 2, "d")
    @test c.valuetype <: Array
    @test d.valuetype <: Array{Int, 1}
    @test e.valuetype <: Array{Float64, 1}

    @test_throws ArgumentError XLSXasJSON.JSONPointer("1")
    @test_throws ArgumentError XLSXasJSON.JSONPointer("a")

    @test_throws MethodError XLSXasJSON.JSONPointer(0)

    a1 = OrderedDict(a)
    
    @test a1["a"] isa AbstractArray
    @test a1["a"][1] isa OrderedDict
    @test a1["a"][1]["c"] |> ismissing

    a1[b] = "b"
    a1[c] = ["c", 1000]
    a1[d] = [1, 2]
    a1[e] = [1., 2.]

    @test a1[b] == "b"
    @test a1[c] == ["c", 1000]
    @test a1[d] == [1, 2]
    @test a1[e] == [1., 2.]
end

@testset "JSONPointer complex" begin
    p = XLSXasJSON.JSONPointer("/3/a/1/b")
    @test p.token == (3, "a", 1, "b")

    d = Dict(p)
    @test d[1] |> ismissing
    @test d[3] isa Dict
    @test d[3]["a"][1] isa Dict

    p = XLSXasJSON.JSONPointer("/1/a/2/b")
    @test p.token == (1, "a", 2, "b")
    d = OrderedDict(p)

    @test d isa Array
    @test d[1] isa OrderedDict
    @test d[1]["a"] isa Array
    @test d[1]["a"][1] |> ismissing
    @test d[1]["a"][2] isa OrderedDict
end

@testset "JSONPointer typecheck" begin
    # a = XLSXasJSON.JSONPointer("/int::Int")

    # d = Dict(a)
    # d[a] = "k"

end

# testdata
@testset "Adobe Spry Examples" begin
# source: https://opensource.adobe.com/Spry/samples/data_region/JSONDataSetSample.html
    f = joinpath(data_path, "examples.xlsx")

    #example1
    jws = JSONWorksheet(f, "example1")
    @test jws[1]["array_any"] == split("100;200;300;400", ";")
    @test jws[1]["array_int"] == [100,200,300,400]
    @test jws[1]["array_float"] == [0.1,0.2,0.3,0.4]

    @test jws[2]["array_any"] == split("500;600;700;800", ";")
    @test jws[2]["array_int"] == [500,600,700,800]
    @test jws[2]["array_float"] == [0.5,0.6,0.7,0.8]

    @test jws[3]["array_any"] == [900]
    @test jws[3]["array_string"] == ["900"]
    @test jws[3]["array_int"] == [900]
    @test jws[3]["array_float"] == [900.0]

    #example2
    jws = JSONWorksheet(f, "example2")
    @test JSON.json(jws) == replace("""[{"color":"red","value":"#f00"},{"color":"green","value":"#0f0"},{"color":"blue","value":"#00f"},{"color":"cyan","value":"#0ff"},{"color":"magenta","value":"#f0f"},{"color":"yellow","value":"#ff0"},{"color":"black","value":"#000"}]""", "\n"=>"")

    #example5
    jws = JSONWorksheet(f, "example5")
    @test isa(jws[1]["batters"]["batter"], Array)
    @test isa(jws[2]["batters"]["batter"], Array)
    @test isa(jws[3]["batters"]["batter"], Array)

    @test isa(jws[1]["topping"], Array)
    @test isa(jws[2]["topping"], Array)
    @test isa(jws[3]["topping"], Array)

    @test jws[1]["batters"]["batter"][1] == OrderedDict("id"=>1001, "type"=>"Regular")
    @test jws[1]["batters"]["batter"][4] == OrderedDict("id"=>1004, "type"=>"Devil's Food")

    @test jws[1]["topping"][1] == OrderedDict("id"=>5001, "type"=>"None")
    @test jws[2]["topping"][2] == OrderedDict("id"=>5002, "type"=>"Glazed")
    @test jws[3]["topping"][3] == OrderedDict("id"=>5003, "type"=>"Chocolate")

    #example6 - xf_coloriented
    jws = JSONWorksheet(f, "example6"; row_oriented = false)
    @test jws[1]["id"] == 1
    @test jws[1]["type"] == "donut"
    @test jws[1]["name"] == "Cake"
    @test jws[1]["image"]["url"] == "images/0001.jpg"
    @test jws[1]["image"]["width"] == 200
    @test jws[1]["image"]["height"] == 2500
    @test jws[1]["thumbnail"]["url"] == "images/thumbnails/0001.jpg"
    @test jws[1]["thumbnail"]["width"] == 32
    @test jws[1]["thumbnail"]["height"] == 32
end


@testset "JSONWorkbook - deleteat!" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jwb = JSONWorkbook(xf)
    @test length(jwb) == 6
    deleteat!(jwb, 1)
    @test length(jwb) == 5

    deleteat!(jwb, :promotion)
    @test length(jwb) == 4
    @test_throws ArgumentError jwb[:promotion]
end


@testset "JSONWorksheet - merge" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jwb = JSONWorkbook(xf)
   
    ws1 = jwb[:mergeA]
    ws2 = jwb[:mergeB]

    @test_throws AssertionError merge(ws1, ws2, "/Something")

    new_sheet = merge(ws1, ws2, "/Key")
    @test collect(keys(new_sheet[1])) == ["Key", "Address", "Name", "Property"]
    @test_throws KeyError jwb[:mergeA][1]["Property"][1]["A"]

    jwb[:mergeA] = new_sheet
    @test keys(jwb[:mergeA][1]) == keys(new_sheet[1])

    @test jwb[:mergeA][1]["Address"]["State"] == "Some"
    @test jwb[:mergeA][1]["Address"]["TEL"] == [555,1111,2222]
    @test jwb[:mergeA][1]["Property"][1]["A"] == "Out"
    @test jwb[:mergeA][1]["Property"][2]["A"] == "think"

    ws3 = jwb[:mergeC]
    new_sheet = merge(ws1, ws3, "/Key")

    @test length(new_sheet) == 6
    @test ws1[1]["Address"]["TEL"] == [555,1111,2222] 
    @test new_sheet[1]["Key"] == ws1[1]["Key"]
    @test new_sheet[2]["Address"] == ws1[2]["Address"]

    @test new_sheet[1]["Address"]["TEL"] == ws3[2]["Address"]["TEL"]
    @test new_sheet[3]["Address"]["TEL"] == ws3[1]["Address"]["TEL"]

end

@testset "JSONWorksheet - append!" begin
    xf = joinpath(data_path, "append.xlsx")
    jwb = JSONWorkbook(xf)

    ws1 = jwb["Sheet1"]
    ws2 = jwb["Sheet2"]
    ws3 = jwb["Sheet3"]

    @test length(ws1) == 1
    @test length(ws2) == 2
    
    append!(ws1, ws2)
    @test length(ws1) == 3
    @test length(ws2) == 2

    @test ws1[2] == ws2[1]
    @test ws1[3] == ws2[2]

    @test_throws AssertionError append!(ws1, ws3)
end 


@testset "XLSX Readng - Asserts" begin
    xf = joinpath(data_path, "assert.xlsx")
    @test_throws AssertionError JSONWorksheet(xf, "dup")
    @test_throws AssertionError JSONWorksheet(xf, "dup2")
    @test_throws AssertionError JSONWorksheet(xf, "dup3")

    @test_throws MethodError JSONWorksheet(xf, "dict_array")
    @test_broken JSONWorksheet(xf, "array_dict")

    @test_throws AssertionError JSONWorksheet(xf, "start_line")
    @test JSONWorksheet(xf, "start_line";start_line=2) isa JSONWorksheet
    @test_throws AssertionError JSONWorksheet(xf, "empty")
end

@testset "XLSX Readng - missingdata" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jws = JSONWorksheet(xf, "Missing")

    @test size(jws) == (5, 4)
    @test ismissing(jws[4]["Data"]["A"])
    @test all(broadcast(el -> ismissing(el["AllNull"]), jws))
    @test collect(keys(jws[1])) == ["Key", "Data", "AllNull"]
end

@testset "XLSX Readng - type" begin
    xf = joinpath(data_path, "othercase.xlsx")
    data = JSONWorksheet(xf, "promotion")
    @test isa(data[1]["t1"]["A"], Integer)
    @test isa(data[1]["t1"]["B"], Bool)

    @test isa(data[1]["t2"]["A"], Integer)
    @test isa(data[1]["t2"]["B"], Float64)

    @test isa(data[1]["t3"]["A"], Integer)
    @test isa(data[1]["t3"]["B"], Bool)
    @test isa(data[1]["t3"]["C"], Float64)
end

@testset "XLSX Readng - delim" begin
    xf = joinpath(data_path, "delim.xlsx")
    data = JSONWorksheet(xf, "Sheet1"; delim = r";|,")

    @test  data[1]["Array_1"] == ["a", "b", "c"]
    @test  data[2]["Array_1"] == ["d", "e", "f"]
    @test  data[3]["Array_1"] == ["g", "h", "i"]
    @test  data[1]["Array_2"] == [1,2,3]
    @test  data[2]["Array_2"] == [4,5,6]
    @test  data[3]["Array_2"] == [7,8,9]
end