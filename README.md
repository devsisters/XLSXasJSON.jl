# XLSXasJSON [[KR](https://github.com/devsisters/XLSXasJSON.jl/blob/master/README_kr.md)]
[![License][license-img]](LICENSE)
<!-- [![travis][travis-img]][travis-url] -->
<!-- [![appveyor][appveyor-img]][appveyor-url] -->
<!-- [![codecov][codecov-img]][codecov-url] -->

[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

Inspired by [excel-as-json](https://github.com/stevetarver/excel-as-json)

## Usage
Parse Excel xlsx files into a Julia data structure to write them as a JSON encoded file.

You may organize Excel data by columns or rows where the first column or row contains object key names and the remaining columns/rows contain object values.

Expected use is offline translation of Excel data to JSON files

## Installation

```julia
pkg> add https://github.com/devsisters/XLSXasJSON.jl
```

## Usage

``` julia
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

| color|
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

| color.name|color.value|
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

| a.b.c.d.e.f|
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


#### Vector{T} where T
An embedded array key name looks like this and has ';' delimited values. You can also decide DataType of array

| array()    |array_int(Int)|array_float(float)|
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

#### Vector{Dict}
A dotted key name looks like

| phones.[1,number]|
| ----------------|
| 123.456.7890|

and produces

```json
[{
  "phones": [{
      "number": "123.456.7890"
    }]
}]
```

#### All of the above

Now you know all the rules necessary to create any json data structure you want with just a column name
This is a more complete row oriented example

| a.b | a.b2(Int) | a.b3.[1,Type] | a.b3.[1,Amount] | a.b3.[2,Type] | a.b3.[2,Amount] | a.b3.[3,Type] | a.b3.[3,Amount()] |
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
