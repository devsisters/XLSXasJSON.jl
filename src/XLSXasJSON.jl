module XLSXasJSON

using Printf, REPL
using JSON
using JSONPointer
using JSONPointer: Pointer
using XLSX
using OrderedCollections

include("index.jl")
include("jsonpointer.jl")
include("worksheet.jl")
include("tables.jl")
include("workbook.jl")
include("writer.jl")

export JSONWorkbook, JSONWorksheet, JSONWorksheet2,
        hassheet, sheetnames,
        xlsxpath

end # module
