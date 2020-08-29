
# Tutorial

## Installation

From a Julia session, run:

```julia
julia> using Pkg
julia> Pkg.add("XLSXasJSON")
```

## Usage Exmple
If you are familiar with a [JSONPointer](https://tools.ietf.org/html/rfc6901) you can get start right away with example datas in the test.

### JSONWorkbook 
By default, first rows of each sheets are considered as JSONPointer for data structure. And each sheets are pared to `Array{OrderedDict, 1}` 

``` julia
    using XLSXasJSON

    p = joinpath(dirname(pathof(XLSXasJSON)), "../test/data")
    xf = joinpath(p, "example.xlsx")
    jwb = JSONWorkbook(xf)
```
You can access worksheet via `jwb[1]` or `jwb["sheetname"]`


### JSONWorksheet
``` julia
    using XLSXasJSON

    p = joinpath(dirname(pathof(XLSXasJSON)), "../test/data")
    xf = joinpath(p, "example.xlsx")
    jws = JSONWorksheet(xf, :Sheet1)
```
You can access rows of data with `jws[1, :]` 


### Writing JSON File
``` julia
    using XLSXasJSON

    p = joinpath(dirname(pathof(XLSXasJSON)), "../test/data")
    xf = joinpath(p, "example.xlsx")
    jwb = JSONWorkbook(xf)

    # Writing whole sheet
    XLSXasJSON.write(pwd(), jwb)
    # Writing singsheet
    XLSXasJSON.write("Sheet1.json", jwb[1]; indent = 2)
```
## Arguments

- `row_oriented` : if 'true'(the default) it will look for colum names in '1:1', if `false` it will look for colum names in 'A:A' 
- `start_line` : starting index of position of columnname.
- `squeeze` : squeezes all rows of Worksheet to a singe row.
- `delim` : a String or Regrex that of deliminator for converting single cell to array.


## JSONPointer Exmples

#### Basic
A simple, row oriented key

| /color|
| -----|
| red|

produces

```json
[{
  "color": "red"
}]
```

#### Dict
Nested names looks like:

| /color/name|color/value|
| ----------|-----------|
| red       |#f00       |

and produces

```json
[{
  "color": {
    "name": "red",
    "value": "#f00"
    }
}]
```

It can has as many nests as you want

| /a/b/c/d/e/f|
| ---------------|
| It can be done|

and produces

```json
[{
    "a": {
      "b": {
        "c": {
          "d": {
            "e": {
              "f": "It can be done"
            }
          }
        }
      }
    }
  }]

```
#### Array
Sometimes it's convinient to put array values in seperate column in XLSX 

| /color/name|color/rgb/1|color/rgb/2|color/rgb/3|
| ----|-----|-----|-----|
| red     |255   |0 |0  |

```json
[{
  "color": {
    "name": "red",
    "rgb": [255, 0, 0]
    }
}]
```

#### Type Declarations
You can declare Type with `::` operator the same way as in Julia.
- The value of `Vector` will be splitted with deliminator ';'.
- Only JSON supported types will be checked for validation.

| /array::Vector    |/array_int::Vector{Int}|/array_float::Vector{Float64}|
| ------------| ------------ | ------------|
| 100;200;300 |100;200;300   |100;200;300  |

and produces

```json
[{
  "array": [
    "100",
    "200",
    "300"
  ],
  "array_int": [
    100,
    200,
    300
  ],
  "array_float": [
    100.0,
    200.0,
    300.0
  ]
}]
```

#### All of the above

Now you know all the rules necessary to create any json data structure you want with just a column name.
This is a more complete row-oriented example:

| /a/b | /a/b2::Vector{Int} | /a/b3/1,Type | /a/b3/1/Amount | /a/b3/2/Type | /a/b3/2/Amount | /a/b3/3/Type | /a/b3/3/Amount::Vector |
|------------------|-------------|------|---|------------|---|-----------|-----------|
| Fooood | 100;200;300 | Cake | 50 | Chocolate | 19 | Ingredient | Salt;100 |

would produce
```json
[
  {
    "a": {
      "b": "Fooood",
      "b2": [
        100,
        200,
        300
      ],
      "b3": [
        {
          "Type": "Cake",
          "Amount": 50
        },
        {
          "Type": "Chocolate",
          "Amount": 19
        },
        {
          "Type": "Ingredient",
          "Amount": [
            "Salt",
            "100"
          ]
        }
      ]
    }
  }
]

```
