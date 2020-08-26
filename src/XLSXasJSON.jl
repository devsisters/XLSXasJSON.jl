module XLSXasJSON

using Printf, REPL
using JSON
using XLSX
using OrderedCollections
using JSONPointer
import JSONPointer.Pointer

include("index.jl")
# include("pointer.jl")
include("worksheet.jl")
include("workbook.jl")
include("writer.jl")

export JSONWorkbook, JSONWorksheet,
        hassheet, sheetnames,
        xlsxpath, dropnull

end # module
