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

| address.street|
| ---------------|
| 12 Beaver Court|

and produces

```json
[{
  "address": {
    "street": "12 Beaver Court"
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
An embedded array key name looks like this and has ';' delimited values. You can also decide datatype in array

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
You can add delim string with `push!(XLSXasJSON.DELIM, ",")`

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
some examples are

deep.dict.vec() | deep.dict.dictarray[1,A] | deep.dict.dictarray[1,B(Float)] |
----------------| ------------------------ | ------------------------------  | 
100;200;300     | plain string             | 0.1;0.2;0.3                     |


#### Sumary
A more complete row oriented example

firstName | lastName | address.street  | address.city | address.state | address.zip
--------- | -------- | --------------- | ------------ | ------------- | -----------
Jihad     | Saladin  | 12 Beaver Court | Snowmass     | CO            | 81615
Marcus    | Rivapoli | 16 Vail Rd      | Vail         | CO            | 81657

would produce

```json
[{
    "firstName": "Jihad",
    "lastName": "Saladin",
    "address": {
      "street": "12 Beaver Court",
      "city": "Snowmass",
      "state": "CO",
      "zip": "81615"
    }
  },
  {
    "firstName": "Marcus",
    "lastName": "Rivapoli",
    "address": {
      "street": "16 Vail Rd",
      "city": "Vail",
      "state": "CO",
      "zip": "81657"
    }
  }]
```
You can do something similar in column oriented sheets. with `row_oriented = false` keyword argument. 

firstName            | Jihad            | Marcus
:------------------- | :--------------- | :-----------
**lastName**         | Saladin          | Rivapoli
**address.street**   | 12 Beaver Court  | 16 Vail Rd
**address.city**     | Snowmass         | Vail
**address.state**    | CO               | CO
**address.zip()** | 81;615            | 81;657
**phones[0,type]**   | home             | home
**phones[0,number(Int)]** | 123;456;7890     | 123;456;7891
**phones[1,type]**   | work             | work
**phones[1,number(Int)]** | 098;765;4321     | 098;765;4322
**aliases()**        | stormagedden;bob | mac;markie

would produce


```json
[
  {
    "firstName": "Jihad",
    "lastName": "Saladin",
    "address": {
      "street": "12 Beaver Court",
      "city": "Snowmass",
      "state": "CO",
      "zip": ["81","615"]
    },
    "phones": [
      {
        "type": "home",
        "number": [123, 456, 7890]
      },
      {
        "type": "work",
        "number": [098, 765, 4321]
      }
    ],
    "aliases": [
      "stormagedden",
      "bob"
    ]
  },
  {
    "firstName": "Marcus",
    "lastName": "Rivapoli",
    "address": {
      "street": "16 Vail Rd",
      "city": "Vail",
      "state": "CO",
      "zip": ["81", "657"]
    },
    "phones": [
      {
        "type": "home",
        "number": [123, 456, 7891]
      },
      {
        "type": "work",
        "number": [098, 765, 4322]
      }
    ],
    "aliases": [
      "mac",
      "markie"
    ]
  }
]
```
