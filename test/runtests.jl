using Test
using XLSXasJSON
using DataStructures
using JSON

import XLSXasJSON.XLSXWrapperMeta
import XLSXasJSON.XLSXWrapperData

data_path = joinpath(@__DIR__, "data")

@testset "Datatype decision" begin
    data = ["a" "b()" "c(Int)" "d(Float)"]
    meta = XLSXWrapperMeta(data)
    @test meta["a"][1] == Any
    @test meta["b()"][1] == Array{Any, 1}
    @test meta["c(Int)"][1] == Array{Int, 1}
    @test meta["d(Float)"][1] == Array{Float64, 1}
end

@testset "Colname splitting" begin
    data = ["a" "a.[1,d3]" "a.[2,d3]"]
    meta = XLSXWrapperMeta(data)
    @test meta["a"][2] == ["a"]
    @test meta["a.[1,d3]"][2] == ["a", 1, "d3"]
    @test meta["a.[2,d3]"][2] == ["a", 2, "d3"]
end

# testdata
@testset "Adobe Spry Examples" begin
# source: https://opensource.adobe.com/Spry/samples/data_region/JSONDataSetSample.html
    f = joinpath(data_path, "examples.xlsx")
    jwb = JSONWorkbook(f)

    #example1
    data = jwb[:example1].data
    @test data[1]["array_any"] == split("100;200;300;400", ";")
    @test data[1]["array_int"] == [100,200,300,400]
    @test data[1]["array_float"] == [0.1,0.2,0.3,0.4]

    @test data[2]["array_any"] == split("500;600;700;800", ";")
    @test data[2]["array_int"] == [500,600,700,800]
    @test data[2]["array_float"] == [0.5,0.6,0.7,0.8]

    @test data[3]["array_any"] == [900]
    @test data[3]["array_string"] == ["900"]
    @test data[3]["array_int"] == [900]
    @test data[3]["array_float"] == [900.0]

    #example2
    data = jwb[:example2].data
    JSON.json(data) == replace("""[{"color":"red","value":"#f00"},{"color":"green","value":"#0f0"},{"color":"blue","value":"#00f"},{"color":"cyan","value":"#0ff"},{"color":"magenta","value":"#f0f"},{"color":"yellow","value":"#ff0"},{"color":"black","value":"#000"}]""", "\n"=>"")

    #example5
    data = jwb[:example5].data
    @test isa(data[1]["batters"]["batter"], Array)
    @test isa(data[2]["batters"]["batter"], Array)
    @test isa(data[3]["batters"]["batter"], Array)

    @test isa(data[1]["topping"], Array)
    @test isa(data[2]["topping"], Array)
    @test isa(data[3]["topping"], Array)

    @test data[1]["batters"]["batter"][1] == OrderedDict("id"=>1001, "type"=>"Regular")
    @test data[1]["batters"]["batter"][4] == OrderedDict("id"=>1004, "type"=>"Devil's Food")

    @test data[1]["topping"][1] == OrderedDict("id"=>5001, "type"=>"None")
    @test data[2]["topping"][2] == OrderedDict("id"=>5002, "type"=>"Glazed")
    @test data[3]["topping"][3] == OrderedDict("id"=>5003, "type"=>"Chocolate")

    #example6 - xf_coloriented
    data = JSONWorksheet(f, :example6; row_oriented=false).data
    
    @test data[1]["id"] == 1
    @test data[1]["type"] == "donut"
    @test data[1]["name"] == "Cake"
    @test data[1]["image"]["url"] == "images/0001.jpg"
    @test data[1]["image"]["width"] == 200
    @test data[1]["image"]["height"] == 2500
    @test data[1]["thumbnail"]["url"] == "images/thumbnails/0001.jpg"
    @test data[1]["thumbnail"]["width"] == 32
    @test data[1]["thumbnail"]["height"] == 32
end


@testset "JSONWorkbook - deleteat!" begin
    xf = joinpath(data_path, "examples.xlsx")
    jwb = JSONWorkbook(xf)
    @test length(jwb) == 4
    deleteat!(jwb, 1)
    @test length(jwb) == 3

    deleteat!(jwb, :example5)
    @test length(jwb) == 2
    @test_throws ArgumentError jwb[:example5]
end


@testset "XLSX Readng - merge" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jwb = JSONWorkbook(xf)
   
    ws1 = jwb[:mergeA]
    ws2 = jwb[:mergeB]

    @test_throws MethodError merge(ws1, ws2, :Key)

    new_sheet = merge(ws1, ws2, "Key")
    @test collect(keys(new_sheet[1])) == ["Key", "Address", "Name", "Property"]

    jwb[:mergeA] = new_sheet
    @test keys(jwb[:mergeA][1]) == keys(new_sheet[1])

    @test jwb[:mergeA][1]["Address"]["State"] == "Some"
    @test jwb[:mergeA][1]["Address"]["TEL"] == [555,1111,2222]
    @test jwb[:mergeA][1]["Property"][1]["A"] == "Out"
    @test jwb[:mergeA][1]["Property"][2]["A"] == "think"
end

@testset "XLSX Readng - Asserts" begin
    xf = joinpath(data_path, "assert.xlsx")
    @test_throws AssertionError JSONWorksheet(xf, "dup")
    @test_throws AssertionError JSONWorksheet(xf, "dup2")
    @test_throws AssertionError JSONWorksheet(xf, "dup3")

    @test_throws AssertionError JSONWorksheet(xf, "start_line")
    @test isa(JSONWorksheet(xf, "start_line";start_line=2), JSONWorksheet)
    @test_throws AssertionError JSONWorksheet(xf, "empty")
end

@testset "XLSX Readng - missingdata" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jws = JSONWorksheet(xf, "Missing")
    data = jws.data

    @test size(jws) == (5, 4)
    @test ismissing(data[4]["Data"]["A"])
    @test all(broadcast(el -> ismissing(el["AllNull"]), data))
    @test collect(keys(jws.data[1])) == ["Key", "Data", "AllNull"]
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

@testset "XLSX Readng - add_delim(WIP)" begin
    xf = joinpath(data_path, "othercase.xlsx")
    # XLSXasJSON.add_delim!(",")
    data = JSONWorksheet(xf, "adddelim")

    @test  data[1]["Array_1"] == ["a", "b", "c"]
    @test  data[2]["Array_1"] == ["d", "e", "f"]
    @test  data[1]["Array_2"] == [1,2,3]
    @test  data[2]["Array_2"] == [4,5,6]
end