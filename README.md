# XLSXasJSON
![LICENSE MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)
![Run CI on master](https://github.com/devsisters/XLSXasJSON.jl/workflows/Run%20CI%20on%20master/badge.svg)
[![Converage](https://github.com/devsisters/XLSXasJSON.jl/blob/gh-pages/dev/coverage/badge_linecoverage.svg)](https://devsisters.github.io/XLSXasJSON.jl/dev/coverage/index.html)

**Documentation**: [Docs](https://devsisters.github.io/XLSXasJSON.jl/dev/)
<!-- [![][docs-latest-img]][docs-latest-url] -->


Inspired by [excel-as-json](https://github.com/stevetarver/excel-as-json)

## Usage
Parse Excel xlsx files into a Julia data structure to write them as a JSON encoded file. 

Designated row or colum must be standardized [JSONPointer](https://tools.ietf.org/html/rfc6901) token, remaining rows will passed to json encoded file.

## Installation

```julia
pkg> add XLSXasJSON
```
