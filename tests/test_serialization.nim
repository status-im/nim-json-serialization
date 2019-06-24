import
  strutils, unittest,
  serialization/testing/generic_suite,
  ../json_serialization, ./utils,
  ../json_serialization/std/options

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

  HoldsOption = object
    r: ref Simple
    o: Option[Simple]

  HoldsArray = object
    data: seq[int]

  Invalid = object
    distance: Mile

  Reserved = object
    # Using Nim reserved keyword
    `type`: string

template reject(code) =
  static: doAssert(not compiles(code))

borrowSerialization(Meter, int)

proc `==`(lhs, rhs: Meter): bool =
  int(lhs) == int(rhs)

proc `==`(lhs, rhs: ref Simple): bool =
  if lhs.isNil: return rhs.isNil
  if rhs.isNil: return false
  return lhs[] == rhs[]

executeReaderWriterTests Json

proc newSimple(x: int, y: string, d: Meter): ref Simple =
  new result
  result.x = x
  result.y = y
  result.distance = d

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

  test "handle missing fields":
    let json = dedent"""
        {
          "y": "test",
          "distance": 20
        }
      """

    let decoded = Json.decode(json, Simple)

    check:
      decoded.x == 0
      decoded.y == "test"
      decoded.distance.int == 20

  test "arrays are printed correctly":
    var x = HoldsArray(data: @[1, 2, 3, 4])

    check:
      x.toJson(pretty = true) == dedent"""
        {
          "data": [
            1,
            2,
            3,
            4
          ]
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

  test "Using Nim reserved keyword `type`":
    let r = Reserved(`type`: "uint8")
    check:
      r.toJSON == """{"type":"uint8"}"""
      r == Json.decode("""{"type":"uint8"}""", Reserved)

  test "Option types":
    let
      h1 = HoldsOption(o: some Simple(x: 1, y: "2", distance: Meter(3)))
      h2 = HoldsOption(r: newSimple(1, "2", Meter(3)))

    Json.roundtripTest h1, """{"r":null,"o":{"x":1,"y":"2","distance":3}}"""
    Json.roundtripTest h2, """{"r":{"x":1,"y":"2","distance":3},"o":null}"""

