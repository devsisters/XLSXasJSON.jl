# XLSXasJSON [[KR](https://github.com/devsisters/XLSXasJSON.jl/blob/master/README_kr.md)]
![](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)
![](https://github.com/devsisters/XLSXasJSON.jl/workflows/Run%20CI%20on%20master/badge.svg)


## Introduction

Designated row or colum must be standardized [JSONPointer](https://tools.ietf.org/html/rfc6901) token, ramaning rows will passed to json encoded file.

## Usage

``` julia
    using XLSXasJSON, JSON

    p = joinpath(dirname(pathof(XLSXasJSON)), "../test/data")
    xf = joinpath(p, "examples.xlsx")
    jws = JSONWorksheet(xf, :example1)

    # turns into json object
    JSON.json(jws)
    # saves with indent
    XLSXasJSON.write("examples_example1.json", jws; indent = 2)
```

### Examples

#### Any
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
A dotted key name looks like

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

It can has as many layers as you want

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
You can declare Type with `::` operator same way as Julia.
- value of `Vector` will be splitted with deliminator ';'.
- Only json supported types will be checked for validation


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

Now you know all the rules necessary to create any json data structure you want with just a column name
This is a more complete row oriented example

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
You can do same with column oriented sheets. with `row_oriented = false` keyword argument. 
