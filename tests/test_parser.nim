# json-serialization
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[strutils, os, json],
  faststreams,
  unittest2,
  ../json_serialization/parser,
  ../json_serialization/value_ops,
  ./utils

func toReader(input: string): JsonReader[DefaultFlavor] =
  var stream = unsafeMemoryInput(input)
  JsonReader[DefaultFlavor].init(stream)

suite "Custom iterators":
  test "customIntValueIt":
    var value: int
    var r = toReader"77663399"
    r.customIntValueIt:
      value = value * 10 + it
    check value == 77663399

  test "customNumberValueIt":
    var value: int
    var frac: int
    var exponent: int
    var r = toReader"123.456e789"
    r.customNumberValueIt:
      if part == IntegerPart:
        value = value * 10 + it
      elif part == FractionPart:
        frac = frac * 10 + it
      elif part == ExponentPart:
        exponent = exponent * 10 + it
    check:
      value == 123
      frac == 456
      exponent == 789

  test "customStringValueIt":
    var text: string
    var r = toReader "\"hello \\t world\""
    r.customStringValueIt:
      text.add it

    expect JsonReaderError:
      r.customStringValueIt(10):
        text.add it

    check text == "hello \t world"

suite "Public parser":
  test "parseArray":
    proc parse(r: var JsonReader, list: var seq[bool])
      {.gcsafe, raises: [IOError, JsonReaderError].} =
      r.parseArray:
        list.add r.parseBool()

    var r = toReader"[true, true, false]"
    var list: seq[bool]
    r.parse(list)
    check list.len == 3
    check list == @[true, true, false]

  test "parseArray with idx":
    proc parse(r: var JsonReader, list: var seq[bool])
      {.gcsafe, raises: [IOError, JsonReaderError].} =
      r.parseArray(i):
        list.add (i mod 2) == 0
        list.add r.parseBool()

    var r = toReader"[true, true, false]"
    var list: seq[bool]
    r.parse(list)
    check list.len == 6
    check list == @[true, true, false, true, true, false]

  test "parseObject":
    type
      Duck = object
        id: string
        ok: bool

    proc parse(r: var JsonReader, list: var seq[Duck]) =
      r.parseObject(key):
        list.add Duck(
          id: key,
          ok: r.parseBool()
        )

    var r = toReader "{\"a\": true, \"b\": false}"
    var list: seq[Duck]
    r.parse(list)

    check list.len == 2
    check list == @[Duck(id:"a", ok:true), Duck(id:"b", ok:false)]

  test "parseNumber uint64":
    var r = toReader "-1234.0007e+88"
    let val = r.parseNumber(uint64)
    check:
      val.sign == JsonSign.Neg
      val.integer == 1234
      val.fraction == "0007"
      val.expSign == JsonSign.Pos
      val.exponent == 88

  test "parseNumber string":
    var r = toReader "-1234.0007e+88"
    let val = r.parseNumber(string)
    check:
      val.sign == JsonSign.Neg
      val.integer == "1234"
      val.fraction == "0007"
      val.expSign == JsonSign.Pos
      val.exponent == "88"

  func highPlus(T: type): string =
    result = $(T.high)
    result[^1] = char(result[^1].int + 1)

  func lowMin(T: type): string =
    result = $(T.low)
    result[^1] = char(result[^1].int + 1)

  template testParseIntI(T: type) =
    var r = toReader $(T.high)
    var val = r.parseInt(T)
    check val == T.high

    expect JsonReaderError:
      var r = toReader highPlus(T)
      let val = r.parseInt(T)
      discard val

    r = toReader $(T.low)
    val = r.parseInt(T)
    check val == T.low

    expect JsonReaderError:
      var r = toReader lowMin(T)
      let val = r.parseInt(T)
      discard val

  template testParseIntU(T: type) =
    var r = toReader $(T.high)
    let val = r.parseInt(T)
    check val == T.high

    expect JsonReaderError:
      var r = toReader highPlus(T)
      let val = r.parseInt(T)
      discard val

  test "parseInt uint8":
    testParseIntU(uint8)

  test "parseInt int8":
    testParseIntI(int8)

  test "parseInt uint16":
    testParseIntU(uint16)

  test "parseInt int16":
    testParseIntI(int16)

  test "parseInt uint32":
    testParseIntU(uint32)

  test "parseInt int32":
    testParseIntI(int32)

  test "parseInt uint64":
    testParseIntU(uint64)

  test "parseInt int64":
    testParseIntI(int64)

  test "parseInt portable overflow":
    expect JsonReaderError:
      var r = toReader $(minPortableInt - 1)
      let val = r.parseInt(int64, true)
      discard val

    expect JsonReaderError:
      var r = toReader $(maxPortableInt + 1)
      let val = r.parseInt(int64, true)
      discard val

    when sizeof(int) == 8:
      expect JsonReaderError:
        var r = toReader $(minPortableInt - 1)
        let val = r.parseInt(int, true)
        discard val

      expect JsonReaderError:
        var r = toReader $(maxPortableInt + 1)
        let val = r.parseInt(int, true)
        discard val

  test "parseFloat":
    var
      r = toReader "56.009"
      val = r.parseFloat(float64)
    check val == 56.009

    r = toReader "-56.009e6"
    val = r.parseFloat(float64)
    check val == -56009000.0

  template testParseAsString(fileName: string) =
    try:
      var stream = memFileInput(fileName)
      var r = JsonReader[DefaultFlavor].init(stream)
      let val = r.parseAsString()
      var xr = toReader val.string
      let xval = xr.parseAsString()
      check val == xval
    except JsonReaderError as ex:
      debugEcho ex.formatMsg(fileName)
      check false

  test "parseAsString":
    for fileName in walkDirRec(transformPath):
      let (_, name) = fileName.splitPath()
      if name notin allowedToFail:
        testParseAsString(fileName)

    for fileName in walkDirRec(parsingPath):
      let (_, name) = fileName.splitPath()
      if name.startsWith("y_"):
        testParseAsString(fileName)
      # test cases starts with i_ are allowed to
      # fail or success depending on the implementation details
      elif name.startsWith("i_"):
        if name notin allowedToFail:
          testParseAsString(fileName)

const
  jsonText = """

{
  "string" : "hello world",
  "number" : -123.456,
  "int":    789,
  "bool"  : true    ,
  "null"  : null  ,
  "array"  : [  true, 567.89  ,   "string in array"  , null, [ 123 ] ],
  "object" : {
    "abc"   : 444.008 ,
    "def": false
  }
}

"""

suite "Parse to runtime dynamic structure":
  test "parse to json node":
    var r = toReader(jsonText)
    let n = r.parseJsonNode()
    check:
      n["string"].str == "hello world"
      n["number"].fnum == -123.456
      n["int"].num == 789
      n["bool"].bval == true
      n["array"].len == 5
      n["array"][0].bval == true
      n["array"][1].fnum == 567.89
      n["array"][2].str == "string in array"
      n["array"][3].kind == JNull
      n["array"][4].kind == JArray
      n["array"][4].len == 1
      n["array"][4][0].num == 123
      n["object"]["abc"].fnum == 444.008
      n["object"]["def"].bval == false

  test "parseValue":
    var r = toReader(jsonText)
    let n = r.parseValue(uint64)
    check:
      n["string"].strVal == "hello world"
      n["bool"].boolVal == true
      n["array"].len == 5
      n["array"][0].boolVal == true
      n["array"][2].strVal == "string in array"
      n["array"][3].kind == JsonValueKind.Null
      n["array"][4].kind == JsonValueKind.Array
      n["array"][4].len == 1
      n["object"]["def"].boolVal == false
