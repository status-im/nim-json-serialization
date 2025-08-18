# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[strutils, options],
  unittest2,
  results,
  stew/byteutils,
  serialization,
  ../json_serialization/pkg/results,
  ../json_serialization/std/options,
  ../json_serialization

createJsonFlavor StringyJson

proc writeValue(w: var JsonWriter[StringyJson], value: seq[byte]) =
  w.streamElement(s):
    s.write('"')
    s.write(toHex(value))
    s.write('"')

proc writeValue*(
    w: var JsonWriter[StringyJson], val: SomeInteger) {.raises: [IOError].} =
  writeValue(w, $val)

proc readValue*(r: var JsonReader[StringyJson], v: var SomeSignedInt) =
  try:
    v = type(v) parseBiggestInt readValue(r, string)
  except ValueError as err:
    r.raiseUnexpectedValue("A signed integer encoded as string " & err.msg)

proc readValue*(r: var JsonReader[StringyJson], v: var SomeUnsignedInt) =
  try:
    v = type(v) parseBiggestUInt readValue(r, string)
  except ValueError as err:
    r.raiseUnexpectedValue("An unsigned integer encoded as string " & err.msg)

type
  Container = object
    name: string
    x: int
    y: uint64
    list: seq[int64]

  OptionalFields = object
    one: Opt[string]
    two: Option[int]

  SpecialTypes = object
    one: JsonVoid
    two: JsonNumber[uint64]
    three: JsonNumber[string]
    four: JsonValueRef[uint64]

  ListOnly = object
    list: JsonString

Container.useDefaultSerializationIn StringyJson

createJsonFlavor OptJson
OptionalFields.useDefaultSerializationIn OptJson

const
  jsonText = """
{
  "one": "this text will gone",
  "two": -789.0009E-19,
  "three": 999.776000E+33,
  "four" : {
    "apple": [1, true, "three"],
    "banana": {
      "chip": 123,
      "z": null,
      "v": false
    }
  }
}

"""
  jsonTextWithNullFields = """
{
  "list": null
}
"""

createJsonFlavor NullyFields,
  skipNullFields = true,
  requireAllFields = false

Container.useDefaultSerializationIn NullyFields
ListOnly.useDefaultSerializationIn NullyFields

suite "Test JsonFlavor":
  test "basic test":
    let c = Container(name: "c", x: -10, y: 20, list: @[1'i64, 2, 25])
    let encoded = StringyJson.encode(c)
    check encoded == """{"name":"c","x":"-10","y":"20","list":["1","2","25"]}"""

    let decoded = StringyJson.decode(encoded, Container)
    check decoded == Container(name: "c", x: -10, y: 20, list: @[1, 2, 25])

  test "optional fields":
    let a = OptionalFields(one: Opt.some("hello"))
    let b = OptionalFields(two: some(567))
    let c = OptionalFields(one: Opt.some("burn"), two: some(333))

    let aa = OptJson.encode(a)
    check aa == """{"one":"hello"}"""

    let bb = OptJson.encode(b)
    check bb == """{"two":567}"""

    let cc = OptJson.encode(c)
    check cc == """{"one":"burn","two":333}"""

  test "Write special types":
    let vv = Json.decode(jsonText, SpecialTypes)
    let xx = Json.encode(vv)
    var ww = Json.decode(xx, SpecialTypes)
    ww.three.expSign = JsonSign.Pos # the rest of it should identical to vv
    check:
      ww == vv
      xx == """{"two":-789.0009e-19,"three":999.776000e33,"four":{"apple":[1,true,"three"],"banana":{"chip":123,"z":null,"v":false}}}"""

  test "object with null fields":
    expect JsonReaderError:
      discard Json.decode(jsonTextWithNullFields, Container)
    expect JsonReaderError:
      discard Json.decode(JsonString(jsonTextWithNullFields), Container)

    let x = NullyFields.decode(jsonTextWithNullFields, Container)
    check x.list.len == 0

    # field should not processed at all
    let y = NullyFields.decode(jsonTextWithNullFields, ListOnly)
    check y.list.string.len == 0

  test "Enum value representation primitives":
    when NullyFields.flavorEnumRep() == EnumAsString:
      check true
    elif NullyFields.flavorEnumRep() == EnumAsNumber:
      check false
    elif NullyFields.flavorEnumRep() == EnumAsStringifiedNumber:
      check false

    NullyFields.flavorEnumRep(EnumAsNumber)
    when NullyFields.flavorEnumRep() == EnumAsString:
      check false
    elif NullyFields.flavorEnumRep() == EnumAsNumber:
      check true
    elif NullyFields.flavorEnumRep() == EnumAsStringifiedNumber:
      check false

    NullyFields.flavorEnumRep(EnumAsStringifiedNumber)
    when NullyFields.flavorEnumRep() == EnumAsString:
      check false
    elif NullyFields.flavorEnumRep() == EnumAsNumber:
      check false
    elif NullyFields.flavorEnumRep() == EnumAsStringifiedNumber:
      check true

  test "Enum value representation of custom flavor":
    type
      ExoticFruits = enum
        DragonFruit
        SnakeFruit
        StarFruit

    NullyFields.flavorEnumRep(EnumAsNumber)
    let u = NullyFields.encode(DragonFruit)
    check u == "0"

    NullyFields.flavorEnumRep(EnumAsString)
    let v = NullyFields.encode(SnakeFruit)
    check v == "\"SnakeFruit\""

    NullyFields.flavorEnumRep(EnumAsStringifiedNumber)
    let w = NullyFields.encode(StarFruit)
    check w == "\"2\""

  test "EnumAsString of custom flavor":
    type
      Fruit = enum
        Banana = "BaNaNa"
        Apple  = "ApplE"
        JackFruit = "VVV"

    NullyFields.flavorEnumRep(EnumAsString)
    let u = NullyFields.encode(Banana)
    check u == "\"BaNaNa\""

    let v = NullyFields.encode(Apple)
    check v == "\"ApplE\""

    let w = NullyFields.encode(JackFruit)
    check w == "\"VVV\""

    NullyFields.flavorEnumRep(EnumAsStringifiedNumber)
    let x = NullyFields.encode(JackFruit)
    check x == "\"2\""

    NullyFields.flavorEnumRep(EnumAsNumber)
    let z = NullyFields.encode(Banana)
    check z == "0"

  test "custom writer that uses stream":
    let value = @[@[byte 0, 1], @[byte 2, 3]]
    check: StringyJson.encode(value) == """["0001","0203"]"""
