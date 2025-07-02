# Reference

<!-- toc -->

This page provides an overview of the `json_serialization` API - for details, see the
[API reference](./api/).

## Parsing

### Common API

JSON parsing uses the [common serialization API](https://github.com/status-im/nim-serialization?tab=readme-ov-file#common-api), supporting both object-based and dynamic JSON documents:

```nim
{{#include ../examples/reference0.nim:Decode}}
```

### Standalone Reader

A reader can be created from any [faststreams](https://github.com/status-im/nim-faststreams)-compatible stream:

```nim
{{#include ../examples/reference0.nim:Reader}}
```

### Parser options

Parser options allow you to control the strictness and limits of the parser. Set them by passing to `Json.decode` or when initializing the reader:

```nim
let flags = defaultJsonReaderFlags + {allowUnknownFields}

var conf = defaultJsonReaderConf
conf.nestedDepthLimit = 0

let native = Json.decode(
  rawJson, NimServer, flags = flags, conf = conf)
```

[Flavors](#flavors) can be used to override the defaults for some these options.

#### Flags

Flags control aspects of the parser that are not all part of the JSON standard, but commonly found in the wild:

  - **allowUnknownFields [=off]**: Skip unknown fields instead of raising an error.
  - **requireAllFields [=off]**: Raise an error if any required field is missing.
  - **escapeHex [=off]**: Allow `\xHH` escape sequences, which are not standard but common in some languages.
  - **relaxedEscape [=off]**: Allow escaping any character, not just control characters.
  - **portableInt [=off]**: Restrict integers to the safe JavaScript range (`-2^53 + 1` to `2^53 - 1`).
  - **trailingComma [=on]**: Allow trailing commas after the last object member or array element.
  - **allowComments [=on]**: Allow C-style comments (`//...` and `/* ... */`).
  - **leadingFraction [=on]**: Accept numbers like `.123`, which are not valid JSON but often used.
  - **integerPositiveSign [=on]**: Accept numbers like `+123`, for symmetry with negative numbers.

#### Limits

Parser limits are passed to `decode`, similar to flags:

You can adjust these defaults to suit your needs:

  - **nestedDepthLimit [=512]**: Maximum nesting depth for objects and arrays (0 = unlimited).
  - **arrayElementsLimit [=0]**: Maximum number of array elements (0 = unlimited).
  - **objectMembersLimit [=0]**: Maximum number of key-value pairs in an object (0 = unlimited).
  - **integerDigitsLimit [=128]**: Maximum digits in the integer part of a number.
  - **fractionDigitsLimit [=128]**: Maximum digits in the fractional part of a number.
  - **exponentDigitsLimit [=32]**: Maximum digits in the exponent part of a number.
  - **stringLengthLimit [=0]**: Maximum string length in bytes (0 = unlimited).

### Special types

  - **JsonString**: Holds a JSON fragment as a distinct string.
  - **JsonVoid**: Skips a valid JSON value.
  - **JsonNumber**: Holds a JSON number, including fraction and exponent.
    - This is a generic type supporting `uint64` and `string` as parameters.
    - The parameter determines the type for the integer and exponent parts.
    - If `uint64` is used, overflow or digit limits may apply.
    - If `string` is used, only digit limits apply.
    - The fraction part is always a string to preserve leading zeros.
  - **JsonValueRef**: Holds any valid JSON value, similar to `std/json.JsonNode`, but uses `JsonNumber` instead of `int` or `float`.

## Writing

### Common API

Similar to parsing, the [common serialization API]() is used to produce JSON documents.

```nim
{{#include ../examples/reference0.nim:Encode}}
```

### Standalone Writer

```nim
{{#include ../examples/reference0.nim:Writer}}
```

## Flavors

Flags and limits are runtime configurations, while a flavor is a compile-time mechanism to prevent conflicts between custom serializers for the same type. For example, a JSON-RPC-based API might require that numbers are formatted as hex strings while the same type exposed through REST should use a number.

Flavors ensure the compiler selects the correct serializer for each subsystem. Use `useDefaultSerializationIn` to assign serializers of a flavor to a specific type.

```nim
# Parameters for `createJsonFlavor`:

  FlavorName: untyped
  mimeTypeValue = "application/json"
  automaticObjectSerialization = false
  requireAllFields = true
  omitOptionalFields = true
  allowUnknownFields = true
  skipNullFields = false
```

```nim
type
  OptionalFields = object
    one: Opt[string]
    two: Option[int]

createJsonFlavor OptJson
OptionalFields.useDefaultSerializationIn OptJson
```

- `automaticObjectSerialization`: By default, all object types are accepted by `json_serialization` - disable automatic object serialization to only serialize explicitly allowed types
- `omitOptionalFields`: Writer ignores fields with null values.
- `skipNullFields`: Reader ignores fields with null values.

## Custom parsers and writers

Parsing and writing can be customized by providing overloads for the `readValue` and `writeValue` functions. Overrides are commonly used with a [flavor](#flavors) that prevents automatic object serialization, to avoid that some objects use the default serialization, should an import be forgotten.

```nim
# Custom serializers for MyType should match the following signatures
proc readValue*(r: var JsonReader, v: var MyType) {.raises: [IOError, SerializationError].}
proc writeValue*(w: var JsonWriter, v: MyType) {.raises: [IOError].}

# When flavors are used, add the flavor as well
proc readValue*(r: var JsonReader[MyFlavor], v: var MyType) {.raises: [IOError, SerializationError].}
proc writeValue*(w: var JsonWriter[MyFlavor], v: MyType) {.raises: [IOError].}
```

The JsonReader provides access to the JSON token stream coming out of the lexer. While the token stream can be accessed directly, there are several helpers that make it easier to correctly parse common JSON shapes.

### Objects

Decode objects using the `parseObject` template. To parse values, use helper functions or `readValue`. The `readObject` and `readObjectFields` iterators are also useful for custom object parsers.

```nim
proc readValue*(r: var JsonReader, table: var Table[string, int]) =
  parseObject(r, key):
    table[key] = r.parseInt(int)
```

### Sets and List-like Types

Sets and list/array-like structures can be parsed using the `parseArray` template, which supports both indexed and non-indexed forms.

Built-in `readValue` implementations exist for regular `seq` and `array`. For `set` or set-like types, you must provide your own implementation.

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

## Custom Iterators

Custom iterators provide access to sub-token elements:

```nim
customIntValueIt(r: var JsonReader; body: untyped)
customNumberValueIt(r: var JsonReader; body: untyped)
customStringValueIt(r: var JsonReader; limit: untyped; body: untyped)
customStringValueIt(r: var JsonReader; body: untyped)
```

## Convenience Iterators

```nim
readArray(r: var JsonReader, ElemType: typedesc): ElemType
readObjectFields(r: var JsonReader, KeyType: type): KeyType
readObjectFields(r: var JsonReader): string
readObject(r: var JsonReader, KeyType: type, ValueType: type): (KeyType, ValueType)
```

## Helper Procedures

When writing a custom serializer, use these safe and intuitive parsers. Avoid using the lexer directly.

```nim
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
parseObjectWithoutSkip(r: var JsonReader, key: untyped, body: untyped)
parseObjectSkipNullFields(r: var JsonReader, key: untyped, body: untyped)
parseObjectCustomKey(r: var JsonReader, keyAction: untyped, body: untyped)
parseJsonNode(r: var JsonReader): JsonNode
skipSingleJsValue(r: var JsonReader)
readRecordValue[T](r: var JsonReader, value: var T)
```

## JsonWriter Helper Procedures

```nim
beginRecord(w: var JsonWriter, T: type)
beginRecord(w: var JsonWriter)
endRecord(w: var JsonWriter)

writeObject(w: var JsonWriter, T: type)
writeObject(w: var JsonWriter)

writeFieldName(w: var JsonWriter, name: string)
writeField(w: var JsonWriter, name: string, value: auto)

iterator stepwiseArrayCreation[C](w: var JsonWriter, collection: C): auto
writeIterable(w: var JsonWriter, collection: auto)
writeArray[T](w: var JsonWriter, elements: openArray[T])

writeNumber[F,T](w: var JsonWriter[F], value: JsonNumber[T])
writeJsonValueRef[F,T](w: var JsonWriter[F], value: JsonValueRef[T])
```

## Enums

```nim
type
  Fruit = enum
    Apple = "Apple"
    Banana = "Banana"

  Drawer = enum
    One
    Two

  Number = enum
    Three = 3
    Four = 4

  Mixed = enum
    Six = 6
    Seven = "Seven"
```

`json_serialization` automatically detects the expected representation for each enum based on its declaration.
- `Fruit` expects string literals.
- `Drawer` and `Number` expect numeric literals.
- `Mixed` (with both string and numeric values) is disallowed by default.
If the JSON literal does not match the expected style, an exception is raised.
You can configure individual enum types:

```nim
configureJsonDeserialization(
    T: type[enum], allowNumericRepr: static[bool] = false,
    stringNormalizer: static[proc(s: string): string] = strictNormalize)

# Example:
Mixed.configureJsonDeserialization(allowNumericRepr = true) # Only at top level
```

You can also configure enum encoding at the flavor or type level:

```nim
type
  EnumRepresentation* = enum
    EnumAsString
    EnumAsNumber
    EnumAsStringifiedNumber

# Examples:

# Flavor level
Json.flavorEnumRep(EnumAsString)   # Default flavor, can be called from non-top level
Flavor.flavorEnumRep(EnumAsNumber) # Custom flavor, can be called from non-top level

# Individual enum type, regardless of flavor
Fruit.configureJsonSerialization(EnumAsNumber) # Only at top level

# Individual enum type for a specific flavor
MyJson.flavorEnumRep(Drawer, EnumAsString) # Only at top level
```
