module XLSXasJSON

using Printf
using JSON
using XLSX
using DataStructures
using DataFrames
import DataFrames.AbstractDataFrame

include("reader.jl")
include("writer.jl")

export XLSXWrapperMeta, XLSXWrapperData, 
JSONWorkbook, JSONWorksheet
        hassheet, sheetnames,
        xlsxpath,
        dropnull

end # module
