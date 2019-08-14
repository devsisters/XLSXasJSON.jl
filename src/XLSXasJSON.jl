module XLSXasJSON

using Printf
using JSON
using XLSX
using DataStructures

include("index.jl")
include("reader.jl")
include("writer.jl")

export JSONWorkbook, JSONWorksheet,
        hassheet, sheetnames,
        xlsxpath, dropnull

end # module
