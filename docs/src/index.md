
# XLSXasJSON.jl

## Introduction

**XLSXasJSON.jl** is a Julia package to convert Excel spread sheet to json encoded file.
Designated row or colum must be standardized [JSONPointer](https://tools.ietf.org/html/rfc6901) token, ramaning rows will passed to json encoded file.

You can read whole workbook, or specify sheet you want to read from Excel file.
each rows on excel sheets are pared to `Array{OrderedDict, 1}` in Julia. 

Please report bugs or make a feature request to [opening an issue](https://github.com/devsisters/XLSXasJSON.jl/issues/new)






## Tutorial

```@contents
Pages = ["tutorial.md"
]
Depth = 1
```