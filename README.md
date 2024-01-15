# nim-json-serialization

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-json-serialization/workflows/CI/badge.svg)

Flexible JSON serialization does not rely on run-time type information.

## Overview
nim-json-serialization offers rich features on top of [nim-serialization](https://github.com/status-im/nim-serialization)
framework. The following is available but not an exhaustive list of features:

  - Decode into Nim data types efficiently without an intermediate token.
  - Able to parse full spec of JSON including the notorious JSON number.
  - Support stdlib/JsonNode out of the box.
  - While stdlib/JsonNode does not support the full spec of the Json number, we offer an alternative `JsonValueRef`.
  - Skipping Json value is an efficient process, no token is generated at all and at the same time, the grammar is checked.
    - Skipping is also free from custom serializer interference.
  - An entire Json value can be parsed into a valid Json document string. This string document can be parsed again without losing any information.
  - Custom serialization is easy and safe to implement with the help of many built-in parsers.
  - Nonstandard features are put behind flags. You can choose which features to switch on or off.
  - Because the intended usage of this library will be in a security-demanding application, we make sure malicious inputs will not crash
    this library through fuzz tests.
  - The user also can tweak certain limits of the lexer/parser behavior using the configuration object.
  - `createJsonFlavor` is a powerful way to prevent cross contamination between different subsystem using different custom serializar on the same type.

## Spec compliance
nim-json-serialization implements [RFC8259](https://datatracker.ietf.org/doc/html/rfc8259)
JSON spec and pass these test suites:

  - [JSONTestSuite](https://github.com/nst/JSONTestSuite)

## Switchable features
Many of these switchable features are widely used features in various projects but are not standard JSON features.
But you can access them using the flags:

  - **allowUnknownFields[=off]**: enable unknown fields to be skipped instead of throwing an error.
  - **requireAllFields[=off]**: if one of the required fields is missing, the serializer will throw an error.
  - **escapeHex[=off]**: JSON doesn't support `\xHH` escape sequence, but it is a common thing in many languages.
  - **relaxedEscape[=off]**: only '0x00'..'0x1F' can be prepended by escape char `\\`, turn this on and you can escape any char.
  - **portableInt[=off]**: set the limit of integer to `-2**53 + 1` and `+2**53 - 1`.
  - **trailingComma[=on]**: allow the presence of a trailing comma after the last object member or array element.
  - **allowComments[=on]**: JSOn standard doesn't mention about comments. Turn this on to parse both C style comments of `//..EOL` and `/* .. */`.
  - **leadingFraction[=on]**: something like `.123` is not a valid JSON number, but its widespread usage sometimes creeps into Json documents.
  - **integerPositiveSign[=on]**: `+123` is also not a valid JSON number, but since `-123` is a valid JSON number, why not parse it safely?

## Safety features
You can modify these default configurations to suit your needs.

  - **nestedDepthLimit: 512**: maximum depth of the nested structure, they are a combination of objects and arrays depth(0=disable).
  - **arrayElementsLimit: 0**: maximum number of allowed array elements(0=disable).
  - **objectMembersLimit: 0**: maximum number of key-value pairs in an object(0=disable).
  - **integerDigitsLimit: 128**: limit the maximum digits of the integer part of JSON number.
  - **fractionDigitsLimit: 128**: limit the maximum digits of faction part of JSON number.
  - **exponentDigitsLimit: 32**: limit the maximum digits of the exponent part of JSON number.
  - **stringLengthLimit: 0**: limit the maximum bytes of string(0=disable).

## Special types

  - **JsonString**: Use this type if you want to parse a Json value to a valid Json document contained in a string.
  - **JsonVoid**: Use this type to skip a valid Json value.
  - **JsonNumber**: Use this to parse a valid Json number including the fraction and exponent part.
    - Please note that this type is a generic, it support `uint64` and `string` as generic param.
    - The generic param will define the integer and exponent part as `uint64` or `string`.
    - If the generic param is `uint64`, overflow can happen, or max digit limit will apply.
    - If the generic param is `string`, the max digit limit will apply.
    - The fraction part is always a string to keep the leading zero of the fractional number.
  - **JsonValueRef**: Use this type to parse any valid Json value into something like stdlib/JsonNode.
    - `JsonValueRef` is using `JsonNumber` instead of `int` or `float` like stdlib/JsonNode.

## Flavor

While flags and limits are runtime configuration, flavor is a powerful compile time mechanism to prevent
cross contamination between different custom serializer operated the same type. For example,
`json-rpc` subsystem dan `json-rest` subsystem maybe have different custom serializer for the same `UInt256`.

Json-Flavor will make sure, the compiler picks the right serializer for the right subsystem.
You can use `useDefaultSerializationIn` to add serializers of a flavor to a specific type.

```Nim
# These are the parameters you can pass to `createJsonFlavor` to create a new flavor.

  FlavorName: untyped
  mimeTypeValue = "application/json"
  automaticObjectSerialization = false
  requireAllFields = true
  omitOptionalFields = true
  allowUnknownFields = true
  skipNullFields = false
```

```Nim
type
  OptionalFields = object
    one: Opt[string]
    two: Option[int]

createJsonFlavor OptJson
OptionalFields.useDefaultSerializationIn OptJson
```

## Decoder example
```nim
  type
    NimServer = object
      name: string
      port: int

    MixedServer = object
      name: JsonValueRef
      port: int

    StringServer = object
      name: JsonString
      port: JsonString

  # decode into native Nim
  var nim_native = Json.decode(rawJson, NimServer)

  # decode into mixed Nim + JsonValueRef
  var nim_mixed = Json.decode(rawJson, MixedServer)

  # decode any value into string
  var nim_string = Json.decode(rawJson, StringServer)

  # decode any valid JSON
  var json_value = Json.decode(rawJson, JsonValueRef)
```

## Load and save
```Nim
  var server = Json.loadFile("filename.json", Server)
  var server_string = Json.loadFile("filename.json", JsonString)

  Json.saveFile("filename.json", server)
```

## Objects
Decoding an object can be achieved via the `parseObject` template.
To parse the value, you can use one of the helper functions or use `readValue`.
`readObject` and `readObjectFields` iterators are also handy when creating a custom object parser.

```Nim
proc readValue*(r: var JsonReader, table: var Table[string, int]) =
  parseObject(r, key):
    table[key] = r.parseInt(int)
```

## Sets and list-like
Similar to `Object`, sets and list or array-like data structures can be parsed using
`parseArray` template. It comes in two variations, indexed and non-indexed.

Built-in `readValue` for regular `seq` and `array` is implemented for you.
No built-in `readValue` for `set` or `set-like` is provided, you must overload it yourself depending on your need.

```nim
type
  HoldArray = object
    data: array[3, int]

  HoldSeq = object
    data: seq[int]

  WelderFlag = enum
    TIG
    MIG
    MMA

  Welder = object
    flags: set[WelderFlag]

proc readValue*(r: var JsonReader, value: var HoldArray) =
  # parseArray with index, `i` can be any valid identifier
  r.parseArray(i):
    value.data[i] = r.parseInt(int)

proc readValue*(r: var JsonReader, value: var HoldSeq) =
  # parseArray without index
  r.parseArray:
    let lastPos = value.data.len
    value.data.setLen(lastPos + 1)
    readValue(r, value.data[lastPos])

proc readValue*(r: var JsonReader, value: var Welder) =
  # populating set also okay
  r.parseArray:
    value.flags.incl r.parseInt(int).WelderFlag
```

## Custom iterators
Using these custom iterators, you can have access to sub-token elements.

```Nim
customIntValueIt(r: var JsonReader; body: untyped)
customNumberValueIt(r: var JsonReader; body: untyped)
customStringValueIt(r: var JsonReader; limit: untyped; body: untyped)
customStringValueIt(r: var JsonReader; body: untyped)
```
## Convenience iterators

```Nim
readArray(r: var JsonReader, ElemType: typedesc): ElemType
readObjectFields(r: var JsonReader, KeyType: type): KeyType
readObjectFields(r: var JsonReader): string
readObject(r: var JsonReader, KeyType: type, ValueType: type): (KeyType, ValueType)
```

## Helper procs
When crafting a custom serializer, use these parsers, they are safe and intuitive.
Avoid using the lexer directly.

```Nim
tokKind(r: var JsonReader): JsonValueKind
parseString(r: var JsonReader, limit: int): string
parseString(r: var JsonReader): string
parseBool(r: var JsonReader): bool
parseNull(r: var JsonReader)
parseNumber(r: var JsonReader, T: type): JsonNumber[T: string or uint64]
parseNumber(r: var JsonReader, val: var JsonNumber)
toInt(r: var JsonReader, val: JsonNumber, T: type SomeInteger, portable: bool): T
parseInt(r: var JsonReader, T: type SomeInteger, portable: bool = false): T
toFloat(r: var JsonReader, val: JsonNumber, T: type SomeFloat): T
parseFloat(r: var JsonReader, T: type SomeFloat): T
parseAsString(r: var JsonReader, val: var string)
parseAsString(r: var JsonReader): JsonString
parseValue(r: var JsonReader, T: type): JsonValueRef[T: string or uint64]
parseValue(r: var JsonReader, val: var JsonValueRef)
parseArray(r: var JsonReader; body: untyped)
parseArray(r: var JsonReader; idx: untyped; body: untyped)
parseObject(r: var JsonReader, key: untyped, body: untyped)
parseObjectCustomKey(r: var JsonReader, keyAction: untyped, body: untyped)
parseJsonNode(r: var JsonReader): JsonNode
skipSingleJsValue(r: var JsonReader)
readRecordValue[T](r: var JsonReader, value: var T)
```

## Helper procs of JsonWriter

```Nim
beginRecord(w: var JsonWriter, T: type)
beginRecord(w: var JsonWriter)
endRecord(w: var JsonWriter)

writeFieldName(w: var JsonWriter, name: string)
writeField(w: var JsonWriter, name: string, value: auto)

iterator stepwiseArrayCreation[C](w: var JsonWriter, collection: C): auto
writeIterable(w: var JsonWriter, collection: auto)
writeArray[T](w: var JsonWriter, elements: openArray[T])

writeNumber[F,T](w: var JsonWriter[F], value: JsonNumber[T])
writeJsonValueRef[F,T](w: var JsonWriter[F], value: JsonValueRef[T])
```

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
