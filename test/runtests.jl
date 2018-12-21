using Test
using XLSXasJSON
using JSON

data_path = joinpath(@__DIR__, "../data")

@testset "Colname Determine" begin
    @test XLSXasJSON.parse_keyname("BasicJSONData")[1] == Any
    @test XLSXasJSON.parse_keyname("address.city")[1] == Dict
    @test XLSXasJSON.parse_keyname("aliases[]")[1] == Array{Any, 1}
    @test XLSXasJSON.parse_keyname("phones[0].number")[1] == Array{Dict, 1}
    @test XLSXasJSON.parse_keyname("phones[Int]")[1] == Array{Int64, 1}
    @test XLSXasJSON.parse_keyname("phones[AbstractFloat]")[1] == Array{AbstractFloat, 1}
    @test XLSXasJSON.parse_keyname("phones[String]")[1] == Array{String, 1}
    # @test parse_keyname("phones[Vector]") == Array{Vector, 1}
end

@testset "JSONData Types" begin
    # Basic
    data_basic = ["base", "string", 100, 100.100, missing]
    # Dict
    data_dict = ["dict.A" "dict.B";
             100      100.100;
            "string"  missing]
    # Array{T, 1}
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
    @test JSON.json(d) == """[{"arr":[{"A":"string","B":100},{"A":"STRING","B":1000.1}]},{"arr":[{"B":200},{"A":200.0,"B":2000.1}]}]"""
end

@testset "XLSX Readng - row oriented" begin
    xf_roworiented = joinpath(data_path, "row-oriented.xlsx")
    a = JSONWorksheet(xf_roworiented, 1)
    @test JSON.json(a) == """[{"firstName":"Jihad","lastName":"Saladin","address":{"street":"12 Beaver Court","city":"Snowmass","state":"CO","zip":81615}},{"firstName":"Marcus","lastName":"Rivapoli","address":{"street":"16 Vail Rd","city":"Vail","state":"CO","zip":81657}}]"""

    b = JSONWorksheet(xf_roworiented, 2; start_line=3)
    @test JSON.json(b) == """[{"firstName":"Max","lastName":"Irwin","address":{"street":"123 Fake Street","city":"Rochester","state":"NY","zip":99999}}]"""
    c = JSONWorksheet(xf_roworiented, 3)
    @test JSON.json(c) == replace("""[{"firstName":"Jihad","address":{"state":"CO","zip":81615},
    "petlist":["cat","dog","horse"],"phones":[{"type":"home","number":"123.456.7890"},
    {"type":"work","number":"098.765.4321"}]},{"firstName":"Marcus",
    "address":{"state":"CO","zip":81657},"petlist":["rat","goblin"],
    "phones":[{"type":"home","number":"123.456.7891"},{"type":"work","number":"098.765.4322"}]},
    {"firstName":"Max","address":{"state":"NY","zip":99999},"petlist":["cricket"],"phones":[{"type":"mars","number":"987.654.321"},
    {"type":"moon","number":"555.451.1234"}]}]""", "\n" => "")
end

@testset "XLSX Readng - col oriented" begin
    xf_coloriented = joinpath(data_path, "col-oriented.xlsx")

    a = JSONWorksheet(xf_coloriented, 1; row_oriented=false)
    @test JSON.json(a) == replace("""[
    {"firstName":"Jihad","lastName":"Saladin","address":{"street":"12 Beaver Court","city":"Snowmass","state":"CO","zip":81615},"isEmployee":"true","phones":[{"type":"home","number":"123.456.7890"},
    {"type":"work","number":"098.765.4321"}],"aliases":["stormagedden","bob"]},
    {"firstName":"Marcus","lastName":"Rivapoli","address":{"street":"16 Vail Rd","city":"Vail","state":"CO","zip":81657},"isEmployee":"false","phones":[{"type":"home","number":"123.456.7891"},
    {"type":"work","number":"098.765.4322"}],"aliases":["mac","markie"]}]"""
    , "\n" => "")

    b = JSONWorksheet(xf_coloriented, 2; start_line=2, row_oriented=false)
    @test JSON.json(b) ==replace("""[
    {"firstName":"Max","lastName":"Irwin","address":{"street":"123 Fake Street","city":"Rochester","state":"NY","zip":99999},"isEmployee":"false","phones":[{"type":"home","number":"123.456.7890"},{"type":"work","number":"505-505-1010"}],"aliases":["binarymax","arch"]},{"firstName":"Ham","lastName":"Simpson","address":{"street":"956 Far Street","city":"Alabama","state":"FL","zip":555433},"isEmployee":true,"phones":[{"type":"home","number":"123.444.1123"},{"type":"office","number":"555-101-1022"}],"aliases":["a","b","alphabet","owl"]}
    ]
    """, "\n" => "")
end

@testset "XLSX Readng - compact" begin
    xf = joinpath(data_path, "othercase.xlsx")

    a = JSONWorksheet(xf, "compact"; compact_to_singleline = true)
    @test JSON.json(a) == replace("""[
    {"Name":["SMITH","JOHNSON","WILLIAMS","JONES","BROWN","DAVIS","MILLER","WILSON","MOORE"],
    "Pweight":[1.006,0.81,0.699,0.621,0.621,0.48,0.423,0.34,0.312]}]
    """, "\n" => "")
end

@testset "XLSX Readng - nullhandling" begin
    xf = joinpath(data_path, "othercase.xlsx")

    a = JSONWorksheet(xf, "missing")
    @test JSON.json(a) == replace("""[
    {"Key":"SMITH","Data":{"A":"Pull","B":10},"AllNull":null},
    {"Key":"JOHNSON","Data":{"A":"request","B":15},"AllNull":null},
    {"Key":"NULLS","Data":{"A":"issue","B":null},"AllNull":null},
    {"Key":"MILLER","Data":{"A":null,"B":35},"AllNull":null},
    {"Key":"MICHEAL","Data":{"A":"after","B":50},"AllNull":null}]
    """, "\n" => "")
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
