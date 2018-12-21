# XLSXasJSON [[ENG](https://github.com/devsisters/XLSXasJSON.jl/blob/master/README_kr.md)]

[![License][license-img]](LICENSE)
<!-- [![travis][travis-img]][travis-url] -->
<!-- [![appveyor][appveyor-img]][appveyor-url] -->
<!-- [![codecov][codecov-img]][codecov-url] -->

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
    xf = joinpath(@__DIR__, "../data/row-oriented.xlsx")
    a = JSONWorksheet(xf, 1)
    a = JSONWorksheet(xf, 1; start_line = 1, row_oriented = true)

    # turns into json object
    JSON.json(a)
    # saves with indent
    XLSXasJSON.write("row-oriented_sheet1.json", a; indent = 2)
```

### 컬럼명 규칙

#### Any
아래와 같이 기본적인 컬럼명은

| firstName|
| ---------|
| Jihad|

`.json`으로 아래와 같이 전환됩니다.

```json
[{
  "firstName": "Jihad"
}]
```

#### Dict

| address.street|
| ---------------|
| 12 Beaver Court|

`.json`으로 아래와 같이 전환됩니다.

```json
[{
  "address": {
    "street": "12 Beaver Court"
    }
}]
```

#### Vector{Dict}

| phones[0].number|
| ----------------|
| 123.456.7890|

`.json`으로 아래와 같이 전환됩니다.

```json
[{
  "phones": [{
      "number": "123.456.7890"
    }]
}]
```

#### Vector{T} where T

| aliases[]
| ----------------
| stormagedden;bob

`.json`으로 아래와 같이 전환됩니다.

```json
[{
  "aliases": [
    "stormagedden",
    "bob"
  ]
}]
```

#### 종합
앞서 소개한 컬럼명 규칙을 모두 사용하면 아래와 같습니다.

firstName | lastName | address.street  | address.city | address.state | address.zip
--------- | -------- | --------------- | ------------ | ------------- | -----------
Jihad     | Saladin  | 12 Beaver Court | Snowmass     | CO            | 81615
Marcus    | Rivapoli | 16 Vail Rd      | Vail         | CO            | 81657

`.json`으로 아래와 같이 전환됩니다.

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
가로가 아니라 세로로된 시트도 전환이 가능합니다.

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

`.json`으로 아래와 같이 전환됩니다.

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
