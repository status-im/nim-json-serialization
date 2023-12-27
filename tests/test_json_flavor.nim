# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
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
  serialization,
  ../json_serialization/stew/results,
  ../json_serialization/std/options,
  ../json_serialization

createJsonFlavor StringyJson

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
