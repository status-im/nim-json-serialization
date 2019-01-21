import
  strutils, options, unittest,
  serialization/testing/generic_suite,
  ../json_serialization, ./utils

type
  Simple = object
    x: int
    y: string

  Foo = object
    i: int
    b: Bar
    s: string

  Bar = object
    sf: seq[Foo]
    z: ref Simple
    # o: Option[Simple]

executeReaderWriterTests Json

suite "toJson tests":
  test "encode primitives":
    check:
      1.toJson == "1"
      "".toJson == "\"\""
      "abc".toJson == "\"abc\""

  test "simple objects":
    var s = Simple(x: 10, y: "test")

    check:
      s.toJson == """{"x":10,"y":"test"}"""
      s.toJson(typeAnnotations = true) == """{"$type":"Simple","x":10,"y":"test"}"""
      s.toJson(pretty = true) == dedent"""
        {
          "x": 10,
          "y": "test"
        }
      """

  test "max unsigned value":
    var uintVal = not uint64(0)
    let jsonValue = Json.encode(uintVal)
    check:
      jsonValue == "18446744073709551615"
      Json.decode(jsonValue, uint64) == uintVal

    expect JsonReaderError:
      discard Json.decode(jsonValue, uint64, mode = Portable)

