# json-serialization
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/json,
  faststreams,
  unittest2,
  serialization,
  ../json_serialization/reader

createJsonFlavor NullFields,
  skipNullFields = true

func toReader(input: string): JsonReader[DefaultFlavor] =
  var stream = unsafeMemoryInput(input)
  JsonReader[DefaultFlavor].init(stream)

func toReaderNullFields(input: string): JsonReader[NullFields] =
  var stream = unsafeMemoryInput(input)
  JsonReader[NullFields].init(stream)

const
  jsonText = """

{
  "string" : "hello world",
  "number" : -123.456,
  "int":    789,
  "bool"  : true    ,
  "null"  : null  ,
  "array"  : [  true, 567.89  ,   "string in array"  , null, [ 123 ] ]
}

"""

  jsonText2 = """

{
  "string" : 25,
  "number" : 123,
  "int":    789,
  "bool"  : 22    ,
  "null"  : 0 ,
}

"""

  jsonText3 = """

{
    "one": [1,true,null],
    "two": 123,
    "three": "help",
    "four": "012",
    "five": "345",
    "six": true,
    "seven": 555,
    "eight": "mTwo",
    "nine": 77,
    "ten": 88,
    "eleven": 88.55,
    "twelve": [true, false],
    "thirteen": [3,4],
    "fourteen": {
      "one": "world",
      "two": false
    }
}

"""

type
  MasterEnum = enum
    mOne
    mTwo
    mThree

  SecondObject = object
    one: string
    two: bool

  MasterReader = object
    one: JsonString
    two: JsonNode
    three: string
    four: seq[char]
    five: array[3, char]
    six: bool
    seven: ref int
    eight: MasterEnum
    nine: int32
    ten: float64
    eleven: float64
    twelve: seq[bool]
    thirteen: array[mTwo..mThree, int]
    fourteen: SecondObject

  SpecialTypes = object
    `string`: JsonVoid
    `number`: JsonNumber[uint64]
    `int`   : JsonNumber[string]
    `bool`  : JsonValueRef[uint64]
    `null`  : JsonValueRef[uint64]
    `array` : JsonString

suite "JsonReader basic test":
  test "readArray iterator":
    var r = toReader "[false, true, false]"
    var list: seq[bool]
    for x in r.readArray(bool):
      list.add x
    check list == @[false, true, false]

  test "readObjectFields iterator":
    var r = toReader jsonText
    var keys: seq[string]
    var vals: seq[string]
    for key in r.readObjectFields(string):
      keys.add key
      let val = r.parseAsString()
      vals.add val.string
    check keys == @["string", "number", "int",  "bool",  "null", "array"]

  test "readObject iterator":
    var r = toReader jsonText2
    var keys: seq[string]
    var vals: seq[uint64]
    for k, v in r.readObject(string, uint64):
      keys.add k
      vals.add v

    check:
      keys == @["string", "number", "int",  "bool",  "null"]
      vals == @[25'u64, 123, 789, 22, 0]

  test "readValue":
    try:
      var r = toReader jsonText3
      var valOrig: MasterReader
      r.readValue(valOrig)
      # workaround for https://github.com/nim-lang/Nim/issues/24274
      let val = valOrig
      check:
        val.one == JsonString("[1,true,null]")
        val.two.num == 123
        val.three ==  "help"
        val.four ==  "012"
        val.five ==  "345"
        val.six ==  true
        val.seven[] == 555
        val.eight ==  mTwo
        val.nine ==  77
        val.ten ==  88
        val.eleven ==  88.55
        val.twelve ==  [true, false]
        val.thirteen ==  [3,4]
        val.fourteen == SecondObject(one: "world", two: false)

    except JsonReaderError as ex:
      debugEcho ex.formatMsg("jsonText3")
      check false

  test "Special Types":
    var r = toReader jsonText
    var val: SpecialTypes
    r.readValue(val)

    check:
      val.`number`.sign == JsonSign.Neg
      val.`number`.integer == 123
      val.`number`.fraction == "456"
      val.`int`.integer == "789"
      val.`bool`.kind == JsonValueKind.Bool
      val.`bool`.boolVal == true
      val.`null`.kind == JsonValueKind.Null
      val.`array`.string == """[true,567.89,"string in array",null,[123]]"""

  proc execReadObjectFields(r: var JsonReader): int =
    for key in r.readObjectFields():
      let val = r.parseAsString()
      discard val
      inc result

  test "readObjectFields of null fields":
    var r = toReaderNullFields("""{"something":null, "bool":true, "string":null}""")
    check execReadObjectFields(r) == 1

    var y = toReader("""{"something":null,"bool":true,"string":"moon"}""")
    check execReadObjectFields(y) == 3

    var z = toReaderNullFields("""{"something":null,"bool":true,"string":"moon"}""")
    check execReadObjectFields(z) == 2

  proc execReadObject(r: var JsonReader): int =
    for k, v in r.readObject(string, int):
      inc result

  test "readObjectFields of null fields":
    var r = toReaderNullFields("""{"something":null, "bool":123, "string":null}""")
    check execReadObject(r) == 1

    expect JsonReaderError:
      var y = toReader("""{"something":null,"bool":78,"string":345}""")
      check execReadObject(y) == 3

    var z = toReaderNullFields("""{"something":null,"bool":999,"string":100}""")
    check execReadObject(z) == 2

  test "readValue of array":
    var r = toReader "[false, true, false]"
    check r.readValue(array[3, bool]) == [false, true, false]

  test "readValue of array error":
    var r = toReader "[false, true, false]"
    expect JsonReaderError:
      discard r.readValue(array[2, bool])
