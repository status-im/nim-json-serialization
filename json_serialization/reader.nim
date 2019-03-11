import
  strutils, typetraits, macros,
  faststreams/input_stream, serialization/object_serialization,
  types, lexer

export
  types

type
  JsonReader* = object
    lexer: JsonLexer

  JsonReaderError* = object of CatchableError
    line*, col*: int

  UnexpectedField* = object of JsonReaderError
    encounteredField*: cstring
    deserializedType*: cstring

  ExpectedTokenCategory* = enum
    etBool = "bool literal"
    etInt = "integer"
    etEnum = "enum value (int or string)"
    etNumber = "number"
    etString = "string"
    etComma = "comma"
    etBracketLe = "array start bracket"
    etBracketRi = "array end bracker"
    etCurrlyLe = "object start bracket"
    etCurrlyRi = "object end bracket"

  UnexpectedToken* = object of JsonReaderError
    encountedToken*: TokKind
    expectedToken*: ExpectedTokenCategory

proc init*(T: type JsonReader, stream: AsciiStreamVar, mode = defaultJsonMode): T =
  result.lexer = JsonLexer.init(stream, mode)
  result.lexer.next()

template init*(T: type JsonReader, stream: ByteStreamVar, mode = defaultJsonMode): auto =
  init JsonReader, AsciiStreamVar(stream), mode

proc setParsed[T: enum](e: var T, s: string) =
  e = parseEnum[T](s)

proc assignLineNumber(ex: ref JsonReaderError, r: JsonReader) =
  ex.line = r.lexer.line
  ex.col = r.lexer.col

proc raiseUnexpectedToken(r: JsonReader, expected: ExpectedTokenCategory) =
  var ex = new UnexpectedToken
  ex.assignLineNumber(r)
  ex.encountedToken = r.lexer.tok
  ex.expectedToken = expected
  raise ex

proc raiseUnexpectedField(r: JsonReader, fieldName, deserializedType: cstring) =
  var ex = new UnexpectedField
  ex.assignLineNumber(r)
  ex.encounteredField = fieldName
  ex.deserializedType = deserializedType
  raise ex

proc requireToken(r: JsonReader, tk: TokKind) =
  if r.lexer.tok != tk:
    r.raiseUnexpectedToken case tk
      of tkString: etString
      of tkInt: etInt
      of tkComma: etComma
      of tkBracketRi: etBracketRi
      of tkBracketLe: etBracketLe
      of tkCurlyRi: etCurrlyRi
      of tkCurlyLe: etCurrlyLe
      else: (assert false; etBool)

proc skipToken(r: var JsonReader, tk: TokKind) =
  r.requireToken tk
  r.lexer.next()

proc readImpl(r: var JsonReader, value: var auto) =
  mixin readValue

  let tok = r.lexer.tok

  when value is string:
    r.requireToken tkString
    value = r.lexer.strVal
    r.lexer.next()

  elif value is bool:
    case tok
    of tkTrue: value = true
    of tkFalse: value = false
    else: r.raiseUnexpectedToken etBool
    r.lexer.next()

  elif value is enum:
    case tok
    of tkString:
      # TODO: don't proprage the `parseEnum` exception
      value.setParsed(r.lexer.strVal)
    of tkInt:
      # TODO: validate that the value is in range
      value = type(value)(r.lexer.intVal)
    else:
      r.raiseUnexpectedToken etEnum
    r.lexer.next()

  elif value is SomeInteger:
    type TargetType = type(value)
    r.requireToken tkInt
    value = TargetType(r.lexer.intVal)
    r.lexer.next()

  elif value is SomeFloat:
    case tok
    of tkInt: value = float(r.lexer.intVal)
    of tkFloat: value = r.lexer.floatVal
    else:
      r.raiseUnexpectedToken etNumber
    r.lexer.next()

  elif value is seq:
    r.skipToken tkBracketLe
    if r.lexer.tok != tkBracketRi:
      while true:
        let lastPos = value.len
        value.setLen(lastPos + 1)
        readValue(r, value[lastPos])
        if r.lexer.tok != tkComma: break
        r.lexer.next()
    r.skipToken tkBracketRi

  elif value is array:
    r.skipToken tkBracketLe
    for i in low(value) ..< high(value):
      # TODO: dont's ask. this makes the code compile
      if false: value[i] = value[i]
      readValue(r, value[i])
      r.skipToken tkComma
    readValue(r, value[high(value)])
    r.skipToken tkBracketRi

  elif value is (object or tuple):
    type T = value.type
    r.skipToken tkCurlyLe

    when T.totalSerializedFields > 0:
      let fields = T.fieldReadersTable(JsonReader)
      var expectedFieldPos = 0
      while r.lexer.tok == tkString:
        let reader = findFieldReader(fields[], r.lexer.strVal, expectedFieldPos)
        r.lexer.next()
        r.skipToken tkColon
        if reader != nil:
          reader(value, r)
        else:
          const typeName = typetraits.name(T)
          r.raiseUnexpectedField(r.lexer.strVal, typeName)
        if r.lexer.tok == tkComma:
          r.lexer.next()
        else:
          break

    r.skipToken tkCurlyRi

  else:
    const typeName = typetraits.name(value.type)
    {.error: "Failed to convert to JSON an unsupported type: " & typeName.}

template readValue*(r: var JsonReader, value: var auto) =
  readImpl(r, value)

