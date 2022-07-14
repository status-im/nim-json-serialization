import
  strutils, unittest, json,
  serialization/object_serialization,
  serialization/testing/generic_suite,
  ../json_serialization, ./utils,
  ../json_serialization/lexer,
  ../json_serialization/std/[options, sets, tables],
  ../json_serialization/stew/results

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

  HasJsonString = object
    name: string
    data: JsonString
    id: int

  HasJsonNode = object
    name: string
    data: JsonNode
    id: int

  HasCstring = object
    notNilStr: cstring
    nilStr: cstring

  # Customised parser tests
  FancyInt = distinct int
  FancyUInt = distinct uint
  FancyText = distinct string

  HasFancyInt = object
    name: string
    data: FancyInt

  HasFancyUInt = object
    name: string
    data: FancyUInt

  HasFancyText = object
    name: string
    data: FancyText

  TokenRegistry = tuple
    entry, exit: TokKind
    dup: bool

  HoldsResultOpt* = object
    o*: Opt[Simple]
    r*: ref Simple

  WithCustomFieldRule* = object
    str*: string
    intVal*: int

  OtherOptionTest* = object
    a*: Option[Meter]
    b*: Option[Meter]

  NestedOptionTest* = object
    c*: Option[OtherOptionTest]
    d*: Option[OtherOptionTest]

  SeqOptionTest* = object
    a*: seq[Option[Meter]]
    b*: Meter

  OtherOptionTest2* = object
    a*: Option[Meter]
    b*: Option[Meter]
    c*: Option[Meter]

var
  customVisit: TokenRegistry

Json.useCustomSerialization(WithCustomFieldRule.intVal):
  read:
    try:
      parseInt reader.readValue(string)
    except ValueError:
      reader.raiseUnexpectedValue("string encoded integer expected")
  write:
    writer.writeValue $value

template registerVisit(reader: var JsonReader; body: untyped): untyped =
  if customVisit.entry == tkError:
    customVisit.entry = reader.lexer.lazyTok
    body
    customVisit.exit = reader.lexer.lazyTok
  else:
    customVisit.dup = true

# Customised parser referring to other parser
proc readValue(reader: var JsonReader, value: var FancyInt) =
  reader.registerVisit:
    value = reader.readValue(int).FancyInt

# Customised numeric parser for integer and stringified integer
proc readValue(reader: var JsonReader, value: var FancyUInt) =
  reader.registerVisit:
    var accu = 0u
    case reader.lexer.lazyTok
    of tkNumeric:
      reader.lexer.customIntValueIt:
        accu = accu * 10u + it.uint
    of tkQuoted:
      var s =  ""
      reader.lexer.customTextValueIt:
        s &= it
      accu = s.parseUInt
    else:
      discard
    value = accu.FancyUInt
  reader.lexer.next

# Customised numeric parser for text, accepts embedded quote
proc readValue(reader: var JsonReader, value: var FancyText) =
  reader.registerVisit:
    var (s, esc) = ("",false)
    reader.lexer.customBlobValueIt:
      let c = it.chr
      if esc:
        s &= c
        esc = false
      elif c == '\\':
        esc = true
      elif c != '"':
        s &= c
      else:
        doNext = StopSwallowByte
    value = s.FancyText
  reader.lexer.next


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
      s.toJson(pretty = true) == test_dedent"""
        {
          "distance": 20,
          "x": 10,
          "y": "test"
        }
      """

  test "handle missing fields":
    let json = test_dedent"""
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

  test "handle additional fields":
    let json = test_dedent"""
        {
          "x": -20,
          "futureObject": {"a": -1, "b": [1, 2.0, 3.1], "c": null, "d": true},
          "futureBool": false,
          "y": "y value"
        }
      """

    let decoded = Json.decode(json, Simple, allowUnknownFields = true)

    check:
      decoded.x == -20
      decoded.y == "y value"
      decoded.distance.int == 0

    expect UnexpectedField:
      let shouldNotDecode = Json.decode(json, Simple)
      echo "This should not have decoded ", shouldNotDecode

  test "all fields are required and present":
    let json = test_dedent"""
        {
          "x": 20,
          "distance": 10,
          "y": "y value"
        }
      """

    let decoded = Json.decode(json, Simple, requireAllFields = true)

    check:
      decoded.x == 20
      decoded.y == "y value"
      decoded.distance.int == 10

  test "all fields were required, but not all were provided":
    let json = test_dedent"""
      {
        "x": -20,
        "distance": 10
      }
    """

    expect IncompleteObjectError:
      let shouldNotDecode = Json.decode(json, Simple, requireAllFields = true)
      echo "This should not have decoded ", shouldNotDecode

  test "all fields were required, but not all were provided (additional fields present instead)":
    let json = test_dedent"""
      {
        "futureBool": false,
        "y": "y value",
        "futureObject": {"a": -1, "b": [1, 2.0, 3.1], "c": null, "d": true},
        "distance": 10
      }
    """

    expect IncompleteObjectError:
      let shouldNotDecode = Json.decode(json, Simple,
                                        requireAllFields = true,
                                        allowUnknownFields = true)
      echo "This should not have decoded ", shouldNotDecode

  test "all fields were required, but none were provided":
    let json = "{}"

    expect IncompleteObjectError:
      let shouldNotDecode = Json.decode(json, Simple, requireAllFields = true)
      echo "This should not have decoded ", shouldNotDecode

  test "all fields are required and provided, and additional ones are present":
    let json = test_dedent"""
      {
        "x": 20,
        "distance": 10,
        "futureBool": false,
        "y": "y value",
        "futureObject": {"a": -1, "b": [1, 2.0, 3.1], "c": null, "d": true},
      }
      """

    let decoded = try:
      Json.decode(json, Simple, requireAllFields = true, allowUnknownFields = true)
    except SerializationError as err:
      checkpoint "Unexpected deserialization failure: " & err.formatMsg("<input>")
      raise

    check:
      decoded.x == 20
      decoded.y == "y value"
      decoded.distance.int == 10

    expect UnexpectedField:
      let shouldNotDecode = Json.decode(json, Simple,
                                        requireAllFields = true,
                                        allowUnknownFields = false)
      echo "This should not have decoded ", shouldNotDecode

  test "arrays are printed correctly":
    var x = HoldsArray(data: @[1, 2, 3, 4])

    check:
      x.toJson(pretty = true) == test_dedent"""
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
      r.toJson == """{"type":"uint8","renamed":"field"}"""
      r == Json.decode("""{"type":"uint8", "renamed":"field"}""", HasUnusualFieldNames)

  test "Option types":
    check:
      2 == static(HoldsOption.totalSerializedFields)
      1 == static(HoldsOption.totalExpectedFields)

      2 == static(Foo.totalSerializedFields)
      2 == static(Foo.totalExpectedFields)

    let
      h1 = HoldsOption(o: some Simple(x: 1, y: "2", distance: Meter(3)))
      h2 = HoldsOption(r: newSimple(1, "2", Meter(3)))
      h3 = Json.decode("""{"r":{"distance":3,"x":1,"y":"2"}}""",
                       HoldsOption, requireAllFields = true)

    Json.roundtripTest h1, """{"r":null,"o":{"distance":3,"x":1,"y":"2"}}"""
    Json.roundtripTest h2, """{"r":{"distance":3,"x":1,"y":"2"}}"""

    check h3 == h2

    expect SerializationError:
     let h4 = Json.decode("""{"o":{"distance":3,"x":1,"y":"2"}}""",
                          HoldsOption, requireAllFields = true)

  test "Nested option types":
    let
      h3 = OtherOptionTest()
      h4 = OtherOptionTest(a: some Meter(1))
      h5 = OtherOptionTest(b: some Meter(2))
      h6 = OtherOptionTest(a: some Meter(3), b: some Meter(4))

    Json.roundtripTest h3, """{}"""
    Json.roundtripTest h4, """{"a":1}"""
    Json.roundtripTest h5, """{"b":2}"""
    Json.roundtripTest h6, """{"a":3,"b":4}"""

    let
      arr = @[some h3, some h4, some h5, some h6, none(OtherOptionTest)]
      results = @[
        """{"c":{},"d":{}}""",
        """{"c":{},"d":{"a":1}}""",
        """{"c":{},"d":{"b":2}}""",
        """{"c":{},"d":{"a":3,"b":4}}""",
        """{"c":{}}""",
        """{"c":{"a":1},"d":{}}""",
        """{"c":{"a":1},"d":{"a":1}}""",
        """{"c":{"a":1},"d":{"b":2}}""",
        """{"c":{"a":1},"d":{"a":3,"b":4}}""",
        """{"c":{"a":1}}""",
        """{"c":{"b":2},"d":{}}""",
        """{"c":{"b":2},"d":{"a":1}}""",
        """{"c":{"b":2},"d":{"b":2}}""",
        """{"c":{"b":2},"d":{"a":3,"b":4}}""",
        """{"c":{"b":2}}""",
        """{"c":{"a":3,"b":4},"d":{}}""",
        """{"c":{"a":3,"b":4},"d":{"a":1}}""",
        """{"c":{"a":3,"b":4},"d":{"b":2}}""",
        """{"c":{"a":3,"b":4},"d":{"a":3,"b":4}}""",
        """{"c":{"a":3,"b":4}}""",
        """{"d":{}}""",
        """{"d":{"a":1}}""",
        """{"d":{"b":2}}""",
        """{"d":{"a":3,"b":4}}""",
        """{}"""
      ]


    var r = 0
    for a in arr:
      for b in arr:
        Json.roundtripTest NestedOptionTest(c: a, d: b), results[r]
        r.inc

    Json.roundtripTest SeqOptionTest(a: @[some 5.Meter, none Meter], b: Meter(5)), """{"a":[5,null],"b":5}"""
    Json.roundtripTest OtherOptionTest2(a: some 5.Meter, b: none Meter, c: some 10.Meter), """{"a":5,"c":10}"""

  test "Result Opt types":
    check:
      false == static(isFieldExpected Opt[Simple])
      2 == static(HoldsResultOpt.totalSerializedFields)
      1 == static(HoldsResultOpt.totalExpectedFields)

    let
      h1 = HoldsResultOpt(o: Opt[Simple].ok Simple(x: 1, y: "2", distance: Meter(3)))
      h2 = HoldsResultOpt(r: newSimple(1, "2", Meter(3)))

    Json.roundtripTest h1, """{"o":{"distance":3,"x":1,"y":"2"},"r":null}"""
    Json.roundtripTest h2, """{"r":{"distance":3,"x":1,"y":"2"}}"""

    let
      h3 = Json.decode("""{"r":{"distance":3,"x":1,"y":"2"}}""",
                       HoldsResultOpt, requireAllFields = true)

    check h3 == h2

    expect SerializationError:
     let h4 = Json.decode("""{"o":{"distance":3,"x":1,"y":"2"}}""",
                          HoldsResultOpt, requireAllFields = true)

  test "Custom field serialization":
    let obj = WithCustomFieldRule(str: "test", intVal: 10)
    Json.roundtripTest obj, """{"str":"test","intVal":"10"}"""

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

  proc testJsonHolders(HasJsonData: type) =
    let
      data1 = test_dedent"""
        {
          "name": "Data 1",
          "data": [1, 2, 3, 4],
          "id": 101
        }
      """
    let
      data2 = test_dedent"""
        {
          "name": "Data 2",
          "data": "some string",
          "id": 1002
        }
      """
    let
      data3 = test_dedent"""
        {
          "name": "Data 3",
          "data": {"field1": 10, "field2": [1, 2, 3], "field3": "test"},
          "id": 10003
        }
      """

    try:
      let
        d1 = Json.decode(data1, HasJsonData)
        d2 = Json.decode(data2, HasJsonData)
        d3 = Json.decode(data3, HasJsonData)

      check:
        d1.name == "Data 1"
        $d1.data == "[1,2,3,4]"
        d1.id == 101

        d2.name == "Data 2"
        $d2.data == "\"some string\""
        d2.id == 1002

        d3.name == "Data 3"
        $d3.data == """{"field1":10,"field2":[1,2,3],"field3":"test"}"""
        d3.id == 10003

      let
        d1Encoded = Json.encode(d1)
        d2Encoded = Json.encode(d2)
        d3Encoded = Json.encode(d3)

      check:
        d1Encoded == $parseJson(data1)
        d2Encoded == $parseJson(data2)
        d3Encoded == $parseJson(data3)

    except SerializationError as e:
      echo e.getStackTrace
      echo e.formatMsg("<>")
      raise e

  test "Holders of JsonString":
    testJsonHolders HasJsonString

  test "Holders of JsonNode":
    testJsonHolders HasJsonNode

  test "Json with comments":
    const jsonContent = staticRead "./cases/comments.json"

    try:
      let decoded = Json.decode(jsonContent, JsonNode)
      check decoded["tasks"][0]["label"] == newJString("nim-beacon-chain build")
    except SerializationError as err:
      checkpoint err.formatMsg("./cases/comments.json")
      check false

  test "A nil cstring":
    let
      obj1 = HasCstring(notNilStr: "foo", nilStr: nil)
      obj2 = HasCstring(notNilStr: "", nilStr: nil)
      str: cstring = "some value"

    check:
      Json.encode(obj1) == """{"notNilStr":"foo","nilStr":null}"""
      Json.encode(obj2) == """{"notNilStr":"","nilStr":null}"""
      Json.encode(str) == "\"some value\""
      Json.encode(cstring nil) == "null"

    reject:
      # Decoding cstrings is not supported due to lack of
      # clarity regarding the memory allocation approach
      Json.decode("null", cstring)

suite "Custom parser tests":
  test "Fall back to int parser":
    customVisit = TokenRegistry.default

    let
      jData = test_dedent"""
        {
          "name": "FancyInt",
          "data": -12345
        }
      """
      dData = Json.decode(jData, HasFancyInt)

    check dData.name == "FancyInt"
    check dData.data.int == -12345
    check customVisit == (tkNumeric, tkCurlyRi, false)

  test "Uint parser on negative integer":
    customVisit = TokenRegistry.default

    let
      jData = test_dedent"""
        {
          "name": "FancyUInt",
          "data": -12345
        }
      """
      dData = Json.decode(jData, HasFancyUInt)

    check dData.name == "FancyUInt"
    check dData.data.uint == 12345u # abs value
    check customVisit == (tkNumeric, tkExNegInt, false)

  test "Uint parser on string integer":
    customVisit = TokenRegistry.default

    let
      jData = test_dedent"""
        {
          "name": "FancyUInt",
          "data": "12345"
        }
      """
      dData = Json.decode(jData, HasFancyUInt)

    check dData.name == "FancyUInt"
    check dData.data.uint == 12345u
    check customVisit == (tkQuoted, tkExBlob, false)

  test "Parser on text blob with embedded quote (backlash escape support)":
    customVisit = TokenRegistry.default

    let
      jData = test_dedent"""
        {
          "name": "FancyText",
          "data": "a\bc\"\\def"
        }
      """
      dData = Json.decode(jData, HasFancyText)

    check dData.name == "FancyText"
    check dData.data.string == "abc\"\\def"
    check customVisit == (tkQuoted, tkExBlob, false)
