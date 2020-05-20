import
  strutils, unittest,
  serialization/object_serialization,
  serialization/testing/generic_suite,
  ../json_serialization, ./utils,
  ../json_serialization/std/[options, sets, tables]

type
  Foo = object
    i: int
    b {.dontSerialize.}: Bar
    s: string

  Bar = object
    sf: seq[Foo]
    z: ref Simple

  Invalid = object
    distance: Mile

  HasUnusualFieldNames = object
    # Using Nim reserved keyword
    `type`: string
    renamedField {.serializedFieldName("renamed").}: string

  MyKind = enum
    Apple
    Banana

  MyCaseObject = object
    name: string
    case kind: MyKind
    of Banana: banana: int
    of Apple: apple: string

  MyUseCaseObject = object
    field: MyCaseObject

# TODO `borrowSerialization` still doesn't work
# properly when it's placed in another module:
Meter.borrowSerialization int

template reject(code) {.used.} =
  static: doAssert(not compiles(code))

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

var invalid = Invalid(distance: Mile(100))
# The compiler cannot handle this check at the moment
# {.fatal.} seems fatal even in `compiles` context
when false: reject invalid.toJson
else: discard invalid

suite "toJson tests":
  test "encode primitives":
    check:
      1.toJson == "1"
      "".toJson == "\"\""
      "abc".toJson == "\"abc\""

  test "simple objects":
    var s = Simple(x: 10, y: "test", distance: Meter(20))

    check:
      s.toJson == """{"distance":20,"x":10,"y":"test"}"""
      s.toJson(typeAnnotations = true) == """{"$type":"Simple","distance":20,"x":10,"y":"test"}"""
      s.toJson(pretty = true) == dedent"""
        {
          "distance": 20,
          "x": 10,
          "y": "test"
        }
      """

  test "handle missing fields":
    let json = dedent"""
        {
          "distance": 20,
          "y": "test"
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

  test "Unusual field names":
    let r = HasUnusualFieldNames(`type`: "uint8", renamedField: "field")
    check:
      r.toJSON == """{"type":"uint8","renamed":"field"}"""
      r == Json.decode("""{"type":"uint8", "renamed":"field"}""", HasUnusualFieldNames)

  test "Option types":
    let
      h1 = HoldsOption(o: some Simple(x: 1, y: "2", distance: Meter(3)))
      h2 = HoldsOption(r: newSimple(1, "2", Meter(3)))

    Json.roundtripTest h1, """{"r":null,"o":{"distance":3,"x":1,"y":"2"}}"""
    Json.roundtripTest h2, """{"r":{"distance":3,"x":1,"y":"2"},"o":null}"""

  test "Case object as field":
    let
      original = MyUseCaseObject(field: MyCaseObject(name: "hello",
                                                     kind: Apple,
                                                     apple: "world"))
      decoded = Json.decode(Json.encode(original), MyUseCaseObject)

    check:
       $original == $decoded

  test "stringLike":
    check:
      "abc" == Json.decode(Json.encode(['a', 'b', 'c']), string)
      "abc" == Json.decode(Json.encode(@['a', 'b', 'c']), string)
      ['a', 'b', 'c'] == Json.decode(Json.encode(@['a', 'b', 'c']), seq[char])
      ['a', 'b', 'c'] == Json.decode(Json.encode("abc"), seq[char])
      ['a', 'b', 'c'] == Json.decode(Json.encode(@['a', 'b', 'c']), array[3, char])

    expect JsonReaderError: # too short
      discard Json.decode(Json.encode(@['a', 'b']), array[3, char])

    expect JsonReaderError: # too long
      discard Json.decode(Json.encode(@['a', 'b']), array[1, char])
