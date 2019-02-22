using Test
using XLSXasJSON
using JSON

data_path = joinpath(@__DIR__, "..", "data")
# data_path = joinpath(@__DIR__, "data")

@testset "Colname Determine" begin
    @test XLSXasJSON.assign_jsontype("BasicJSONData") == Any
    @test XLSXasJSON.assign_jsontype("address.city") == Dict
    @test XLSXasJSON.assign_jsontype("aliases[]") == Array{Any, 1}
    @test XLSXasJSON.assign_jsontype("phones[0].number") == Array{Dict, 1}
    @test XLSXasJSON.assign_jsontype("phones[Int]") == Array{Int64, 1}
    @test XLSXasJSON.assign_jsontype("phones[AbstractFloat]") == Array{AbstractFloat, 1}
    @test XLSXasJSON.assign_jsontype("phones[Float64]") == Array{Float64, 1}
    @test XLSXasJSON.assign_jsontype("phones[String]") == Array{String, 1}
    # @test parse_keyname("phones[Vector]") == Array{Vector, 1}
end

@testset "JSONData Types" begin
    data_basic = ["base", "string", 100, 100.100, missing]
    data_dict = ["dict.A" "dict.B";
             100      100.100;
            "string"  missing]
    data_array = ["Vec1[]" "Vec2[Int]";
             "a;b;c;d"      "500;600;700";
             ";"      "43;25;"]
    # Array{Dict, 1}
    data_array_dict = ["arr[0].A" "arr[0].B" "arr[1].A" "arr[1].B";
             "string" 100 "STRING" 1000.1;
             missing 200 200. 2000.1]

    a = JSONWorksheet(data_basic, "","")
    @test JSON.json(a) == """[{"base":"string"},{"base":100},{"base":100.1},{"base":null}]"""
    b = JSONWorksheet(data_dict, "","")
    @test JSON.json(b) == """[{"dict":{"A":100,"B":100.1}},{"dict":{"A":"string","B":null}}]"""
    c = JSONWorksheet(data_array, "","")
    @test JSON.json(c) == """[{"Vec1":["a","b","c","d"],"Vec2":[500,600,700]},{"Vec1":[],"Vec2":[43,25]}]"""
    d = JSONWorksheet(data_array_dict, "","")
    @test JSON.json(d) == """[{"arr":[{"A":"string","B":100},{"A":"STRING","B":1000.1}]},{"arr":[{"A":null,"B":200},{"A":200.0,"B":2000.1}]}]"""
end

@testset "XLSX Readng - row oriented" begin
    xf_roworiented = joinpath(data_path, "row-oriented.xlsx")
    a = JSONWorksheet(xf_roworiented, 1)
    @test JSON.json(a) == """[{"firstName":"Jihad","lastName":"Saladin","address":{"street":"12 Beaver Court","city":"Snowmass","state":"CO","zip":81615}},{"firstName":"Marcus","lastName":"Rivapoli","address":{"street":"16 Vail Rd","city":"Vail","state":"CO","zip":81657}}]"""

    b = JSONWorksheet(xf_roworiented, 2; start_line=3)
    @test JSON.json(b) == """[{"firstName":"Max","lastName":"Irwin","address":{"street":"123 Fake Street","city":"Rochester","state":"NY","zip":99999}}]"""
    c = JSONWorksheet(xf_roworiented, 3)
    @test JSON.json(c) == replace("""
    [{"firstName":"Jihad","address":{"state":"CO","zip":81615},"petlist":["cat","dog","horse"],"phones":[{"type":"home","number":"123.456.7890"},{"type":"work","number":"098.765.4321"}]},{"firstName":"Marcus","address":{"state":"CO","zip":81657},"petlist":["rat","goblin"],"phones":[{"type":"home","number":"123.456.7891"},{"type":"work","number":"098.765.4322"}]},{"firstName":"Max","address":{"state":"NY","zip":99999},"petlist":["cricket"],"phones":[{"type":"mars","number":"987.654.321"},{"type":"moon","number":"555.451.1234"}]}]""",
    "\n" => "")
end

@testset "XLSX Readng - col oriented" begin
    xf_coloriented = joinpath(data_path, "col-oriented.xlsx")

    a = JSONWorksheet(xf_coloriented, 1; row_oriented=false)
    @test JSON.json(a) == replace("""
    [{"firstName":"Jihad","lastName":"Saladin","address":{"street":"12 Beaver Court","city":"Snowmass","state":"CO","zip":81615},"isEmployee":"true","phones":[{"type":"home","number":"123.456.7890"},{"type":"work","number":"098.765.4321"}],"aliases":["stormagedden","bob"]},{"firstName":"Marcus","lastName":"Rivapoli","address":{"street":"16 Vail Rd","city":"Vail","state":"CO","zip":81657},"isEmployee":"false","phones":[{"type":"home","number":"123.456.7891"},{"type":"work","number":"098.765.4322"}],"aliases":["mac","markie"]}]"""
    , "\n" => "")

    b = JSONWorksheet(xf_coloriented, 2; start_line=2, row_oriented=false)
    @test JSON.json(b) == """[{"firstName":"Max","lastName":"Irwin","address":{"street":"123 Fake Street","city":"Rochester","state":"NY","zip":99999},"isEmployee":"false","phones":[{"type":"home","number":"123.456.7890"},{"type":"work","number":"505-505-1010"}],"aliases":["binarymax","arch"]},{"firstName":"Ham","lastName":"Simpson","address":{"street":"956 Far Street","city":"Alabama","state":"FL","zip":555433},"isEmployee":true,"phones":[{"type":"home","number":"123.444.1123"},{"type":"office","number":"555-101-1022"}],"aliases":["a","b","alphabet","owl"]}]"""
end

@testset "XLSX Readng - compact" begin
    xf = joinpath(data_path, "othercase.xlsx")

    a = JSONWorksheet(xf, "compact"; compact_to_singleline = true)
    @test JSON.json(a) == """[{"Name":["SMITH","JOHNSON","WILLIAMS","JONES","BROWN","DAVIS","MILLER","WILSON","MOORE"],"Pweight":[1.006,0.81,0.699,0.621,0.621,0.48,0.423,0.34,0.312]}]"""
end

@testset "XLSX Readng - nullhandling" begin
    xf = joinpath(data_path, "othercase.xlsx")

    a = JSONWorksheet(xf, "missing")
    data = JSON.json(a)
    @test data == """[{"Key":"SMITH","Data":{"A":"Pull","B":10},"AllNull":null},{"Key":"JOHNSON","Data":{"A":"request","B":15},"AllNull":null},{"Key":"NULLS","Data":{"A":"issue","B":null},"AllNull":null},{"Key":"MILLER","Data":{"A":null,"B":35},"AllNull":null},{"Key":"MICHEAL","Data":{"A":"after","B":50},"AllNull":null}]"""

    @test dropnull(data) == """[{"Key":"SMITH","Data":{"A":"Pull","B":10}},{"Key":"JOHNSON","Data":{"A":"request","B":15}},{"Key":"NULLS","Data":{"A":"issue"}},{"Key":"MILLER","Data":{"B":35}},{"Key":"MICHEAL","Data":{"A":"after","B":50}}]"""
end

@testset "XLSX Readng - add new DELIM" begin
    XLSXasJSON.DELIM = r";|,"

    data_basic = ["DelimThis[]", "one;two;three", "one,two,three"]


    a = JSONWorksheet(data_basic, "","")
    @test JSON.json(a) == """[{"DelimThis":["one","two","three"]},{"DelimThis":["one,two,three"]}]"""

    push!(XLSXasJSON.DELIM, ",")
    a = JSONWorksheet(data_basic, "","")
    @test JSON.json(a) == """[{"DelimThis":["one","two","three"]},{"DelimThis":["one","two","three"]}]"""
end

@testset "XLSX Readng - deleteat! Worksheet" begin
    xf = joinpath(data_path, "othercase.xlsx")

    a = JSONWorkbook(xf)
    @test length(a) == 2
    deleteat!(a, :missing)
    @test length(a) == 1
    @test_throws ArgumentError a[:missing]
end

@testset "XLSX Readng - WorkBook" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jwb = JSONWorkbook(xf)

    @test sheetnames(jwb) == [:compact, :missing]

    @test  jwb[1][:] == JSONWorksheet(xf, 1)[:]
    # @test  jwb[2][:] == JSONWorksheet(xf, 2)[:] cannot compare missing
end

# TODO: manual test works, but autotest fails, needs to check
@testset "JSON Writing" begin
    xf = joinpath(data_path, "othercase.xlsx")
    jwb = JSONWorkbook(xf)

    f1 = joinpath(@__DIR__, "s1.json")
    f2 = joinpath(@__DIR__, "s2.json")

    XLSXasJSON.write(f1, jwb[1])
    XLSXasJSON.write(f2, jwb[2])

    @test isfile(f1)
    @test isa(JSON.parsefile(f1), Vector)

    @test isfile(f2)
    @test isa(JSON.parsefile(f2), Vector)

    rm(f1)
    rm(f2)
end
