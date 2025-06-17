# nim-json-serialization

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-json-serialization/workflows/CI/badge.svg)

## Introduction

<!-- ANCHOR: Features -->

`nim-json-serialization` is a library in the [nim-serialization](https://github.com/status-im/nim-serialization) family for turning Nim objects into JSON documents and back. Features include:

- Efficient coding of JSON documents directly to and from Nim data types
  - Full type-based customization of both parsing and formatting
  - Flavors for defining multiple JSON serialization styles per Nim type
  - Efficient skipping of tags and values for partial JSON parsing
- Flexibility in mixing type-based and dynamic JSON access
  - Structured `JsonValueRef` node type for DOM-style access to parsed document
  - Flat `JsonString` type for passing nested JSON documents between abstraction layers
  - Seamless interoperability with [`std/json`](https://nim-lang.org/docs/json.html) and `JsonNode`
- Full [RFC8259 spec compliance](https://datatracker.ietf.org/doc/html/rfc8259) including the notorious JSON number
  - Passes [JSONTestSuite](https://github.com/nst/JSONTestSuite)
  - Customizable parser strictness including support for non-standard extensions
- Well-defined handling of malformed / malicious inputs with configurable parsing limits
  - Fuzzing and comprehensive manual test coverage

<!-- ANCHOR_END: Features -->

## Getting started

```nim
requires "json_serialization"
```

Create a type and use it to encode and decode JSON:

```nim
import json_serialization

type Request = object
  jsonrpc: string
  `method`: string

let
  json = """{"jsonrpc": "2.0", "method": "name"}"""
  decoded = Json.decode(json, Request)

echo decoded.jsonrpc
echo Json.encode(decoded, pretty=true)
```

## Documentation

See the [user guide](https://status-im.github.io/nim-json-serialization/).

## Contributing

Contributions are welcome - please make sure to add test coverage for features and fixes!

`json_serialization` follows the [Status Nim Style Guide](https://status-im.github.io/nim-style-guide/).

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
