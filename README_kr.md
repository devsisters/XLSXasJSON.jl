# XLSXasJSON [[ENG](https://github.com/devsisters/XLSXasJSON.jl/blob/master/README_kr.md)]

![](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)
![](https://github.com/devsisters/XLSXasJSON.jl/workflows/Run%20CI%20on%20master/badge.svg)

[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

이 패키지의 기능은 [excel-as-json](https://github.com/stevetarver/excel-as-json) 을 참고 하여 개발되었습니다.

## 개요

`.xlsx` 파일을 읽어들여 지정된 컬럼명 규칙에 따라 `.json`데이터로 전환해 줍니다.
엑셀 파일은 첫행 혹은 열이 컬럼명, 나머지 행이나 열이 데이터로 구성되어 있어야합니다.

## 설치 방법
```julia
pkg> add https://github.com/devsisters/XLSXasJSON.jl
```

## 사용법
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

#### Vector{T} where T
An embedded array key name looks like this and has ';' delimited values. You can also specify DataType of array with `(Int)`,`(Float)`,`(String)`

| /array()    |/array_int(Int)|/array_float(Float)|
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

| /a/b | /a/b2(Int) | /a/b3/1,Type | /a/b3/1/Amount | /a/b3/2/Type | /a/b3/2/Amount | /a/b3/3/Type | /a/b3/3/Amount() |
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
