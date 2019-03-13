import
  strutils, options, unittest,
  serialization/testing/generic_suite,
  ../json_serialization, ./utils

type
  Meter = distinct int
  Mile = distinct int

  Simple = object
    x: int
    y: string
    distance: Meter

  Foo = object
    i: int
    b: Bar
    s: string

  Bar = object
    sf: seq[Foo]
    z: ref Simple
    # o: Option[Simple]

  Invalid = object
    distance: Mile

template reject(code) =
  static: doAssert(not compiles(code))

borrowSerialization(Meter, int)

executeReaderWriterTests Json

when false:
  # The compiler cannot handle this check at the moment
  # {.fatal.} seems fatal even in `compiles` context
  var invalid = Invalid(distance: Mile(100))
  reject invalid.toJson

suite "toJson tests":
  test "encode primitives":
    check:
      1.toJson == "1"
      "".toJson == "\"\""
      "abc".toJson == "\"abc\""

  test "simple objects":
    var s = Simple(x: 10, y: "test", distance: Meter(20))

    check:
      s.toJson == """{"x":10,"y":"test","distance":20}"""
      s.toJson(typeAnnotations = true) == """{"$type":"Simple","x":10,"y":"test","distance":20}"""
      s.toJson(pretty = true) == dedent"""
        {
          "x": 10,
          "y": "test",
          "distance": 20
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

