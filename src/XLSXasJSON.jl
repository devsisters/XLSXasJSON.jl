# thanks to: https://github.com/stevetarver/excel-as-json
module XLSXasJSON

using Printf
using JSON
using XLSX
using DataStructures
using DataFrames
import DataFrames.AbstractDataFrame

include("structs.jl")
include("read.jl")
include("write.jl")

export JSONWorkbook, JSONWorksheet,
       hassheet, sheetnames,
       xlsxpath, jsonpath

end
