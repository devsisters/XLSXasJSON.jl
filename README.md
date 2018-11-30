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

Expected use is offline translation of Excel data to JSON files, although all methods are exported for other uses.

## Installation

```julia
pkg> add https://github.com/devsisters/XLSXasJSON.jl
```

## Usage

``` julia
    xf = joinpath(@__DIR__, "../data/row-oriented.xlsx")
    a = JSONWorksheet(xf, 1)
    a = JSONWorksheet(xf, 1; start_line = 1, row_oriented = true)

    # turns into json object
    JSON.json(a)
    # saves with indent
    save_json(a, "row-oriented.json"; indent = 2)
```


### Examples

#### Any
A simple, row oriented key

| firstName|
| ---------|
| Jihad|

produces

```json
[{
  "firstName": "Jihad"
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

#### Vector{Dict}
A dotted key name looks like

| phones[0].number|
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

#### Vector{T} where T
An embedded array key name looks like this and has ';' delimited values

| aliases[]
| ----------------
| stormagedden;bob

and produces

```json
[{
  "aliases": [
    "stormagedden",
    "bob"
  ]
}]
```

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
You can do something similar in column oriented sheets. Note that indexed and flat arrays are added.

firstName            | Jihad            | Marcus
:------------------- | :--------------- | :-----------
**lastName**         | Saladin          | Rivapoli
**address.street**   | 12 Beaver Court  | 16 Vail Rd
**address.city**     | Snowmass         | Vail
**address.state**    | CO               | CO
**address.zip**      | 81615            | 81657
**phones[0].type**   | home             | home
**phones[0].number** | 123.456.7890     | 123.456.7891
**phones[1].type**   | work             | work
**phones[1].number** | 098.765.4321     | 098.765.4322
**aliases[]**        | stormagedden;bob | mac;markie

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
      "zip": "81615"
    },
    "phones": [
      {
        "type": "home",
        "number": "123.456.7890"
      },
      {
        "type": "work",
        "number": "098.765.4321"
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
      "zip": "81657"
    },
    "phones": [
      {
        "type": "home",
        "number": "123.456.7891"
      },
      {
        "type": "work",
        "number": "098.765.4322"
      }
    ],
    "aliases": [
      "mac",
      "markie"
    ]
  }
]
```
