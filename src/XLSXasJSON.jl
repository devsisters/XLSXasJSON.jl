module XLSXasJSON

using Printf
using JSON
using XLSX
using DataStructures
using DataFrames
import DataFrames.AbstractDataFrame

include("reader.jl")
include("writer.jl")

export JSONWorkbook, JSONWorksheet, construct_dataframe!,
        hassheet, sheetnames,
        xlsxpath, dropnull,
        df

end # module
