import
  strutils, unittest,
  serialization/object_serialization,
  serialization/testing/generic_suite,
  ../json_serialization, ./utils,
  ../json_serialization/std/[options, sets]

type
  Meter = distinct int
  Mile = distinct int

  Simple = object
    x: int
    y: string
    distance: Meter
    ignored: int

  Foo = object
    i: int
    b {.dontSerialize.}: Bar
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

  ObjectKind = enum
    A
    B

  CaseObject = object
   case kind: ObjectKind:
   of A:
     a: int
     other: CaseObjectRef
   else:
     b: int

  CaseObjectRef = ref CaseObject

func caseObjectEquals(a, b: CaseObject): bool

func `==`*(a, b: CaseObjectRef): bool =
  let nils = ord(a.isNil) + ord(b.isNil)
  if nils == 0:
    caseObjectEquals(a[], b[])
  else:
    nils == 2

func caseObjectEquals(a, b: CaseObject): bool =
  # TODO This is needed to work-around a Nim overload selection issue
  if a.kind != b.kind: return false

  case a.kind
  of A:
    if a.a != b.a: return false
    a.other == b.other
  of B:
    a.b == b.b

func `==`*(a, b: CaseObject): bool =
  caseObjectEquals(a, b)

template reject(code) =
  static: doAssert(not compiles(code))

borrowSerialization(Meter, int)

Simple.setSerializedFields distance, x, y

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

  test "Using Nim reserved keyword `type`":
    let r = Reserved(`type`: "uint8")
    check:
      r.toJSON == """{"type":"uint8"}"""
      r == Json.decode("""{"type":"uint8"}""", Reserved)

  test "Option types":
    let
      h1 = HoldsOption(o: some Simple(x: 1, y: "2", distance: Meter(3)))
      h2 = HoldsOption(r: newSimple(1, "2", Meter(3)))

    Json.roundtripTest h1, """{"r":null,"o":{"distance":3,"x":1,"y":"2"}}"""
    Json.roundtripTest h2, """{"r":{"distance":3,"x":1,"y":"2"},"o":null}"""

  test "Set types":
    type HoldsSet = object
      a: int
      s: HashSet[string]

    var s1 = toSet([1, 2, 3, 1, 4, 2])
    var s2 = HoldsSet(a: 100, s: toSet(["a", "b", "c"]))

    Json.roundtripTest s1
    Json.roundtripTest s2

  test "Case objects":
    var
      c1 = CaseObjectRef(kind: B, b: 100)
      c2 = CaseObjectRef(kind: A, a: 80, other: CaseObjectRef(kind: B))
      c3 = CaseObject(kind: A, a: 60, other: nil)

    Json.roundtripTest c1
    Json.roundtripTest c2
    Json.roundtripTest c3

