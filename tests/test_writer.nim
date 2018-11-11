import
  strutils, options, unittest,
  json_serialization

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

proc dedent(s: string): string =
  var s = s.strip(leading = false)
  var minIndent = 99999999999
  for l in s.splitLines:
    let indent = count(l, ' ')
    if indent == 0: continue
    if indent < minIndent: minIndent = indent
  result = s.unindent(minIndent)

suite "JSON serialization":
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

