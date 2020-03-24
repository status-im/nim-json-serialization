import
  strutils, typetraits, macros, strformat,
  faststreams/input_stream, serialization/[object_serialization, errors],
  types, lexer

export
  types, errors

type
  JsonReader* = object
    lexer*: JsonLexer

  JsonReaderError* = object of JsonError
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

  GenericJsonReaderError* = object of JsonReaderError
    deserializedField*: string
    innerException*: ref CatchableError

  UnexpectedToken* = object of JsonReaderError
    encountedToken*: TokKind
    expectedToken*: ExpectedTokenCategory

  IntOverflowError* = object of JsonReaderError
    isNegative: bool
    absIntVal: uint64

func valueStr(err: ref IntOverflowError): string =
  if err.isNegative:
    result.add '-'
  result.add($err.absIntVal)

method formatMsg*(err: ref JsonReaderError, filename: string): string =
  fmt"{filename}({err.line}, {err.col}) Error while reading json file"

method formatMsg*(err: ref UnexpectedField, filename: string): string =
  fmt"{filename}({err.line}, {err.col}) Unexpected field '{err.encounteredField}' while deserializing {err.deserializedType}"

method formatMsg*(err: ref UnexpectedToken, filename: string): string =
  fmt"{filename}({err.line}, {err.col}) Unexpected token '{err.encountedToken}' in place of '{err.expectedToken}'"

method formatMsg*(err: ref GenericJsonReaderError, filename: string): string =
  fmt"{filename}({err.line}, {err.col}) Exception encountered while deserializing '{err.deserializedField}': [{err.innerException.name}] {err.innerException.msg}"

method formatMsg*(err: ref IntOverflowError, filename: string): string =
  fmt"{filename}({err.line}, {err.col}) The value '{err.valueStr}' is outside of the allowed range"

template init*(T: type JsonReader, stream: ByteStreamVar, mode = defaultJsonMode): auto =
  init JsonReader, AsciiStreamVar(stream), mode

proc assignLineNumber*(ex: ref JsonReaderError, r: JsonReader) =
  ex.line = r.lexer.line
  ex.col = r.lexer.tokenStartCol

proc raiseUnexpectedToken*(r: JsonReader, expected: ExpectedTokenCategory) {.noreturn.} =
  var ex = new UnexpectedToken
  ex.assignLineNumber(r)
  ex.encountedToken = r.lexer.tok
  ex.expectedToken = expected
  raise ex

proc raiseIntOverflow*(r: JsonReader, absIntVal: uint64, isNegative: bool) {.noreturn.} =
  var ex = new IntOverflowError
  ex.assignLineNumber(r)
  ex.absIntVal = absIntVal
  ex.isNegative = isNegative
  raise ex

proc raiseUnexpectedField*(r: JsonReader, fieldName, deserializedType: cstring) {.noreturn.} =
  var ex = new UnexpectedField
  ex.assignLineNumber(r)
  ex.encounteredField = fieldName
  ex.deserializedType = deserializedType
  raise ex

proc handleReadException*(r: JsonReader,
                          Record: type,
                          fieldName: string,
                          field: auto,
                          err: ref CatchableError) =
  var ex = new GenericJsonReaderError
  ex.assignLineNumber(r)
  ex.deserializedField = fieldName
  ex.innerException = err
  raise ex

proc init*(T: type JsonReader, stream: AsciiStreamVar, mode = defaultJsonMode): T =
  result.lexer = JsonLexer.init(stream, mode)
  result.lexer.next()

proc setParsed[T: enum](e: var T, s: string) =
  e = parseEnum[T](s)

proc requireToken*(r: JsonReader, tk: TokKind) =
  if r.lexer.tok != tk:
    r.raiseUnexpectedToken case tk
      of tkString: etString
      of tkInt, tkNegativeInt: etInt
      of tkComma: etComma
      of tkBracketRi: etBracketRi
      of tkBracketLe: etBracketLe
      of tkCurlyRi: etCurrlyRi
      of tkCurlyLe: etCurrlyLe
      else: (doAssert false; etBool)

proc skipToken*(r: var JsonReader, tk: TokKind) =
  r.requireToken tk
  r.lexer.next()

proc allocPtr[T](p: var ptr T) =
  p = create(T)

proc allocPtr[T](p: var ref T) =
  p = new(T)


iterator readArray*(r: var JsonReader, ElemType: typedesc): ElemType =
  mixin readValue

  r.skipToken tkBracketLe
  if r.lexer.tok != tkBracketRi:
    while true:
      var res: ElemType
      readValue(r, res)
      yield res
      if r.lexer.tok != tkComma: break
      r.lexer.next()
  r.skipToken tkBracketRi

iterator readObject*(r: var JsonReader, KeyType: typedesc, ValueType: typedesc): (KeyType, ValueType) =
  mixin readValue

  r.skipToken tkCurlyLe
  if r.lexer.tok != tkCurlyRi:
    while true:
      var key: KeyType
      var value: ValueType
      readValue(r, key)
      if r.lexer.tok != tkColon: break
      r.lexer.next()
      readValue(r, value)
      yield (key, value)
      if r.lexer.tok != tkComma: break
      r.lexer.next()
  r.skipToken tkCurlyRi

func maxAbsValue(T: type[SomeInteger]): uint64 {.compileTime.} =
  when T is int8 : 128'u64
  elif T is int16: 32768'u64
  elif T is int32: 2147483648'u64
  elif T is int64: 9223372036854775808'u64
  else: uint64(high(T))

proc readValue*(r: var JsonReader, value: var auto) =
  mixin readValue

  let tok {.used.} = r.lexer.tok

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

  elif value is ref|ptr:
    if tok == tkNull:
      value = nil
      r.lexer.next()
    else:
      allocPtr value
      value[] = readValue(r, type(value[]))

  elif value is enum:
    case tok
    of tkString:
      # TODO: don't proprage the `parseEnum` exception
      value.setParsed(r.lexer.strVal)
    of tkInt:
      # TODO: validate that the value is in range
      value = type(value)(r.lexer.absIntVal)
    else:
      r.raiseUnexpectedToken etEnum
    r.lexer.next()

  elif value is SomeInteger:
    type TargetType = type(value)
    const maxValidValue = maxAbsValue(TargetType)

    if r.lexer.absIntVal > maxValidValue:
      r.raiseIntOverflow r.lexer.absIntVal, tok == tkNegativeInt

    case tok
    of tkInt:
      value = TargetType(r.lexer.absIntVal)
    of tkNegativeInt:
      when value is SomeSignedInt:
        if r.lexer.absIntVal == maxValidValue:
          # We must handle this as a special case because it would be illegal
          # to convert a value like 128 to int8 before negating it. The max
          # int8 value is 127 (while the minimum is -128).
          value = low(TargetType)
        else:
          value = -TargetType(r.lexer.absIntVal)
      else:
        r.raiseIntOverflow r.lexer.absIntVal, true
    else:
      r.raiseUnexpectedToken etInt
    r.lexer.next()

  elif value is SomeFloat:
    case tok
    of tkInt: value = float(r.lexer.absIntVal)
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
    type T = type(value)
    r.skipToken tkCurlyLe

    when T.totalSerializedFields > 0:
      let fields = T.fieldReadersTable(JsonReader)
      var expectedFieldPos = 0
      while r.lexer.tok == tkString:
        when T is tuple:
          var reader = fields[][expectedFieldPos].reader
          expectedFieldPos += 1
        else:
          var reader = findFieldReader(fields[], r.lexer.strVal, expectedFieldPos)
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
