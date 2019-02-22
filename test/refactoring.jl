using Test
using XLSXasJSON
using JSON
using DataStructures
using DataFrames

import XLSXasJSON.assign_jsontype



const JSONColumnType = (
(Vector{Dict},r"\[(\d+)\]\.(.+)$", x -> split(x, ".")), # abc[1].key
(Dict,        r"\.(.+)",           x -> split(x, ".")), #abc.key
(Vector{T} where T, r"(\[(\D+)\]$)",   x -> replace(x, r"(\[.+\])" => "")), # abc[Type]
(Vector{Float64}, r"(\[Float64\]$)", x -> replace(x, r"(\[.+\])" => "")), # abc[Float64]       
(Vector{Any},     r"(\[\])",         x -> replace(x, r"(\[.+\])$|(\[\])$" => ""))) # abc[]
# (JSONGroup, r"({})",           x -> replace(x, r"({.+\})$|({})$" => ""))) # abc{}


colnames = ["Any", "Any2", "Vector1[]", "Vector2[Int]", 
"Dict1.a", "Dict1.b", "Dict2.a", "Dict2.b", 
"VectorDict[0].a", "VectorDict[0].b", "VectorDict[1].a", "VectorDict[1].b"]

data = ["a1" 100 "el1;el2;el3" "100;200;300" "Dict1.a" "Dict1.b" "Dict2.a" "Dict2.b" "VectorDict[0].a" "VectorDict[0].b" "VectorDict[1].a" "VectorDict[1].b";
"a2" 200 "el4;el5;el6" "200;300;400" "Dict1.a2" "Dict1.b2" "Dict2.a2" "Dict2.b2" "VectorDict[0].a2" "VectorDict[0].b2" "VectorDict[1].a2" "VectorDict[1].b2"]


arr = [missing "AllMissing" "Normal"; 
       1 missing "A";
       missing missing missing;
       2 missing "b";]


missing_col = ismissing.(arr[1, :]) |> Vector{Bool}
arr = arr[:, broadcast(!, missing_col)]


missing_row = broadcast(r -> all(ismissing.(arr[r, :])), 1:size(arr, 1)) |> Vector{Bool}
arr = arr[broadcast(!, missing_row), :]




filter((i, j) -> ismissing(arr[i]))

string.(arr[1, :]), arr[2:end, :])

dropmissing!(arr[1, :])
dropmissing


