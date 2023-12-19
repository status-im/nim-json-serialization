{.experimental: "notnil".}

import
  std/[enumutils, tables, macros, strformat, typetraits],
  stew/[enums, objects],
  faststreams/inputs, serialization/[formats, object_serialization, errors],
  "."/[format, types, lexer]

from json import JsonNode, JsonNodeKind

export
  enumutils, inputs, format, types, errors

type
  JsonReader*[Flavor = DefaultFlavor] = object
    lexer*: JsonLexer
    allowUnknownFields: bool
    requireAllFields: bool

  JsonReaderError* = object of JsonError
    line*, col*: int

  UnexpectedField* = object of JsonReaderError
    encounteredField*: string
    deserializedType*: cstring

  ExpectedTokenCategory* = enum
    etValue = "value"
    etBool = "bool literal"
    etInt = "integer"
    etEnumAny = "enum value (int / string)"
    etEnumString = "enum value (string)"
    etNumber = "number"
    etString = "string"
    etComma = "comma"
    etColon = "colon"
    etBracketLe = "array start bracket"
    etBracketRi = "array end bracker"
    etCurrlyLe = "object start bracket"
    etCurrlyRi = "object end bracket"

  GenericJsonReaderError* = object of JsonReaderError
    deserializedField*: string
    innerException*: ref CatchableError

  UnexpectedTokenError* = object of JsonReaderError
    encountedToken*: TokKind
    expectedToken*: ExpectedTokenCategory

  UnexpectedValueError* = object of JsonReaderError

  IncompleteObjectError* = object of JsonReaderError
    objectType: cstring

  IntOverflowError* = object of JsonReaderError
    isNegative: bool
    absIntVal: BiggestUint

Json.setReader JsonReader

{.push gcsafe, raises: [].}

func valueStr(err: ref IntOverflowError): string =
  if err.isNegative:
    result.add '-'
  result.add($err.absIntVal)

template tryFmt(expr: untyped): string =
  try: expr
  except CatchableError as err: err.msg

method formatMsg*(err: ref JsonReaderError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Error while reading json file: {err.msg}"

method formatMsg*(err: ref UnexpectedField, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Unexpected field '{err.encounteredField}' while deserializing {err.deserializedType}"

method formatMsg*(err: ref UnexpectedTokenError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Unexpected token '{err.encountedToken}' in place of '{err.expectedToken}'"

method formatMsg*(err: ref GenericJsonReaderError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Exception encountered while deserializing '{err.deserializedField}': [{err.innerException.name}] {err.innerException.msg}"

method formatMsg*(err: ref IntOverflowError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) The value '{err.valueStr}' is outside of the allowed range"

method formatMsg*(err: ref UnexpectedValueError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) {err.msg}"

method formatMsg*(err: ref IncompleteObjectError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Not all required fields were specified when reading '{err.objectType}'"

func assignLineNumber*(ex: ref JsonReaderError, lexer: JsonLexer) =
  ex.line = lexer.line
  ex.col = lexer.tokenStartCol

func raiseUnexpectedToken*(lexer: JsonLexer, expected: ExpectedTokenCategory)
                          {.noreturn, raises: [JsonReaderError].} =
  var ex = new UnexpectedTokenError
  ex.assignLineNumber(lexer)
  ex.encountedToken = lexer.lazyTok
  ex.expectedToken = expected
  raise ex

template raiseUnexpectedToken*(reader: JsonReader, expected: ExpectedTokenCategory) =
  raiseUnexpectedToken(reader.lexer, expected)

func raiseUnexpectedValue*(
    lexer: JsonLexer, msg: string) {.noreturn, raises: [JsonReaderError].} =
  var ex = new UnexpectedValueError
  ex.assignLineNumber(lexer)
  ex.msg = msg
  raise ex

template raiseUnexpectedValue*(r: JsonReader, msg: string) =
  raiseUnexpectedValue(r.lexer, msg)

func raiseIntOverflow*(
    lexer: JsonLexer, absIntVal: BiggestUint, isNegative: bool)
    {.noreturn, raises: [JsonReaderError].} =
  var ex = new IntOverflowError
  ex.assignLineNumber(lexer)
  ex.absIntVal = absIntVal
  ex.isNegative = isNegative
  raise ex

template raiseIntOverflow*(r: JsonReader, absIntVal: BiggestUint, isNegative: bool) =
  raiseIntOverflow(r.lexer, absIntVal, isNegative)

func raiseUnexpectedField*(
    lexer: JsonLexer, fieldName: string, deserializedType: cstring)
    {.noreturn, raises: [JsonReaderError].} =
  var ex = new UnexpectedField
  ex.assignLineNumber(lexer)
  ex.encounteredField = fieldName
  ex.deserializedType = deserializedType
  raise ex

template raiseUnexpectedField*(r: JsonReader, fieldName: string, deserializedType: cstring) =
  raiseUnexpectedField(r.lexer, fieldName, deserializedType)

func raiseIncompleteObject*(
    lexer: JsonLexer, objectType: cstring)
    {.noreturn, raises: [JsonReaderError].} =
  var ex = new IncompleteObjectError
  ex.assignLineNumber(lexer)
  ex.objectType = objectType
  raise ex

template raiseIncompleteObject*(r: JsonReader, objectType: cstring) =
  raiseIncompleteObject(r.lexer, objectType)

func handleReadException*(lexer: JsonLexer,
                          Record: type,
                          fieldName: string,
                          field: auto,
                          err: ref CatchableError) {.raises: [JsonReaderError].} =
  var ex = new GenericJsonReaderError
  ex.assignLineNumber(lexer)
  ex.deserializedField = fieldName
  ex.innerException = err
  raise ex

template handleReadException*(r: JsonReader,
                              Record: type,
                              fieldName: string,
                              field: auto,
                              err: ref CatchableError) =
  handleReadException(r.lexer, Record, fieldName, field, err)

proc init*(T: type JsonReader,
           stream: InputStream,
           mode = defaultJsonMode,
           allowUnknownFields = false,
           requireAllFields = false): T {.raises: [IOError].} =
  mixin flavorAllowsUnknownFields, flavorRequiresAllFields
  type Flavor = T.Flavor

  result.allowUnknownFields = allowUnknownFields or flavorAllowsUnknownFields(Flavor)
  result.requireAllFields = requireAllFields or flavorRequiresAllFields(Flavor)
  result.lexer = JsonLexer.init(stream, mode)
  result.lexer.next()

proc requireToken*(lexer: var JsonLexer, tk: TokKind) {.raises: [IOError, JsonReaderError].} =
  if lexer.tok != tk:
    lexer.raiseUnexpectedToken case tk
      of tkString: etString
      of tkInt, tkNegativeInt: etInt
      of tkComma: etComma
      of tkBracketRi: etBracketRi
      of tkBracketLe: etBracketLe
      of tkCurlyRi: etCurrlyRi
      of tkCurlyLe: etCurrlyLe
      of tkColon: etColon
      else: (doAssert false; etBool)

proc skipToken*(lexer: var JsonLexer, tk: TokKind) {.raises: [IOError, JsonReaderError].} =
  lexer.requireToken tk
  lexer.next()

proc parseJsonNode(r: var JsonReader): JsonNode
                  {.gcsafe, raises: [IOError, JsonReaderError].}

proc readJsonNodeField(r: var JsonReader, field: var JsonNode)
                  {.gcsafe, raises: [IOError, JsonReaderError].} =
  if field.isNil.not:
    r.raiseUnexpectedValue("Unexpected duplicated field name")

  r.lexer.next()
  r.lexer.skipToken tkColon

  field = r.parseJsonNode()

proc parseJsonNode(r: var JsonReader): JsonNode =
  const maxIntValue: BiggestUint = BiggestInt.high.BiggestUint + 1

  case r.lexer.tok
  of tkCurlyLe:
    result = JsonNode(kind: JObject)
    r.lexer.next()
    if r.lexer.tok != tkCurlyRi:
      while r.lexer.tok == tkString:
        try:
          r.readJsonNodeField(result.fields.mgetOrPut(r.lexer.strVal, nil))
        except KeyError:
          raiseAssert "mgetOrPut should never raise a KeyError"
        if r.lexer.tok == tkComma:
          r.lexer.next()
        else:
          break
    r.lexer.skipToken tkCurlyRi

  of tkBracketLe:
    result = JsonNode(kind: JArray)
    r.lexer.next()
    if r.lexer.tok != tkBracketRi:
      while true:
        result.elems.add r.parseJsonNode()
        if r.lexer.tok == tkBracketRi:
          break
        else:
          r.lexer.skipToken tkComma
    # Skip over the last tkBracketRi
    r.lexer.next()

  of tkColon, tkComma, tkEof, tkError, tkBracketRi, tkCurlyRi:
    r.raiseUnexpectedToken etValue

  of tkString:
    result = JsonNode(kind: JString, str: r.lexer.strVal)
    r.lexer.next()

  of tkInt:
    if r.lexer.absIntVal > maxIntValue:
      r.raiseIntOverflow(r.lexer.absIntVal, false)
    else:
      result = JsonNode(kind: JInt, num: BiggestInt r.lexer.absIntVal)
      r.lexer.next()

  of tkNegativeInt:
    if r.lexer.absIntVal > maxIntValue + 1:
      r.raiseIntOverflow(r.lexer.absIntVal, true)
    else:
      # `0 - x` is a magical trick that turns the unsigned
      # value into its negative signed counterpart:
      result = JsonNode(kind: JInt, num: cast[BiggestInt](BiggestUint(0) - r.lexer.absIntVal))
      r.lexer.next()

  of tkFloat:
    result = JsonNode(kind: JFloat, fnum: r.lexer.floatVal)
    r.lexer.next()

  of tkTrue:
    result = JsonNode(kind: JBool, bval: true)
    r.lexer.next()

  of tkFalse:
    result = JsonNode(kind: JBool, bval: false)
    r.lexer.next()

  of tkNull:
    result = JsonNode(kind: JNull)
    r.lexer.next()

  of tkQuoted, tkExBlob, tkNumeric, tkExInt, tkExNegInt:
    raiseAssert "generic type " & $r.lexer.lazyTok & " is not applicable"

proc skipSingleJsValue*(lexer: var JsonLexer) {.raises: [IOError, JsonReaderError].}  =
  case lexer.tok
  of tkCurlyLe:
    lexer.next()
    if lexer.tok != tkCurlyRi:
      while true:
        lexer.skipToken tkString
        lexer.skipToken tkColon
        lexer.skipSingleJsValue()
        if lexer.tok == tkCurlyRi:
          break
        lexer.skipToken tkComma
    # Skip over the last tkCurlyRi
    lexer.next()

  of tkBracketLe:
    lexer.next()
    if lexer.tok != tkBracketRi:
      while true:
        lexer.skipSingleJsValue()
        if lexer.tok == tkBracketRi:
          break
        else:
          lexer.skipToken tkComma
    # Skip over the last tkBracketRi
    lexer.next()

  of tkColon, tkComma, tkEof, tkError, tkBracketRi, tkCurlyRi:
    lexer.raiseUnexpectedToken etValue

  of tkString, tkQuoted, tkExBlob,
     tkInt, tkNegativeInt, tkFloat, tkNumeric, tkExInt, tkExNegInt,
     tkTrue, tkFalse, tkNull:
    lexer.next()

template skipSingleJsValue*(r: var JsonReader) =
  skipSingleJsValue(r.lexer)

proc captureSingleJsValue(r: var JsonReader, output: var string) {.raises: [IOError, SerializationError].} =
  r.lexer.renderTok output
  case r.lexer.tok
  of tkCurlyLe:
    r.lexer.next()
    if r.lexer.tok != tkCurlyRi:
      while true:
        r.lexer.renderTok output
        r.lexer.skipToken tkString
        r.lexer.renderTok output
        r.lexer.skipToken tkColon
        r.captureSingleJsValue(output)
        r.lexer.renderTok output
        if r.lexer.tok == tkCurlyRi:
          break
        else:
          r.lexer.skipToken tkComma
    else:
      output.add '}'
    # Skip over the last tkCurlyRi
    r.lexer.next()

  of tkBracketLe:
    r.lexer.next()
    if r.lexer.tok != tkBracketRi:
      while true:
        r.captureSingleJsValue(output)
        r.lexer.renderTok output
        if r.lexer.tok == tkBracketRi:
          break
        else:
          r.lexer.skipToken tkComma
    else:
      output.add ']'
    # Skip over the last tkBracketRi
    r.lexer.next()

  of tkColon, tkComma, tkEof, tkError, tkBracketRi, tkCurlyRi:
    r.raiseUnexpectedToken etValue

  of tkString, tkQuoted, tkExBlob,
     tkInt, tkNegativeInt, tkFloat, tkNumeric, tkExInt, tkExNegInt,
     tkTrue, tkFalse, tkNull:
    r.lexer.next()

func allocPtr[T](p: var ptr T) =
  p = create(T)

func allocPtr[T](p: var ref T) =
  p = new(T)

iterator readArray*(r: var JsonReader, ElemType: typedesc): ElemType {.raises: [IOError, SerializationError].} =
  mixin readValue

  r.lexer.skipToken tkBracketLe
  if r.lexer.lazyTok != tkBracketRi:
    while true:
      var res: ElemType
      readValue(r, res)
      yield res
      if r.lexer.tok != tkComma: break
      r.lexer.next()
  r.lexer.skipToken tkBracketRi

iterator readObjectFields*(r: var JsonReader,
                           KeyType: type): KeyType {.raises: [IOError, SerializationError].} =
  mixin readValue

  r.lexer.skipToken tkCurlyLe
  if r.lexer.lazyTok != tkCurlyRi:
    while true:
      var key: KeyType
      readValue(r, key)
      if r.lexer.lazyTok != tkColon: break
      r.lexer.next()
      yield key
      if r.lexer.lazyTok != tkComma: break
      r.lexer.next()
  r.lexer.skipToken tkCurlyRi

iterator readObject*(r: var JsonReader,
                     KeyType: type,
                     ValueType: type): (KeyType, ValueType) {.raises: [IOError, SerializationError].} =
  mixin readValue

  for fieldName in readObjectFields(r, KeyType):
    var value: ValueType
    readValue(r, value)
    yield (fieldName, value)

func isNotNilCheck[T](x: ref T not nil) {.compileTime.} = discard
func isNotNilCheck[T](x: ptr T not nil) {.compileTime.} = discard

func isFieldExpected*(T: type): bool {.compileTime.} =
  T isnot Option

func totalExpectedFields*(T: type): int {.compileTime.} =
  mixin isFieldExpected,
        enumAllSerializedFields

  enumAllSerializedFields(T):
    if isFieldExpected(FieldType):
      inc result

func setBitInWord(x: var uint, bit: int) {.inline.} =
  let mask = uint(1) shl bit
  x = x or mask

const bitsPerWord = sizeof(uint) * 8

func expectedFieldsBitmask*(TT: type): auto {.compileTime.} =
  type T = TT

  mixin isFieldExpected,
        enumAllSerializedFields

  const requiredWords =
    (totalSerializedFields(T) + bitsPerWord - 1) div bitsPerWord

  var res: array[requiredWords, uint]

  var i = 0
  enumAllSerializedFields(T):
    if isFieldExpected(FieldType):
      res[i div bitsPerWord].setBitInWord(i mod bitsPerWord)
    inc i

  res

template setBitInArray[N](data: var array[N, uint], bitIdx: int) =
  when data.len > 1:
    setBitInWord(data[bitIdx div bitsPerWord], bitIdx mod bitsPerWord)
  else:
    setBitInWord(data[0], bitIdx)

func isBitwiseSubsetOf[N](lhs, rhs: array[N, uint]): bool =
  for i in low(lhs) .. high(lhs):
    if (lhs[i] and rhs[i]) != lhs[i]:
      return false

  true

# this construct catches `array[N, char]` which otherwise won't decompose into
# openArray[char] - we treat any array-like thing-of-characters as a string in
# the output
template isCharArray[N](v: array[N, char]): bool = true
template isCharArray(v: auto): bool = false

func parseStringEnum[T](
    r: var JsonReader, value: var T,
    stringNormalizer: static[proc(s: string): string]) {.raises: [JsonReaderError].} =
  try:
    value = genEnumCaseStmt(
      T, r.lexer.strVal,
      default = nil, ord(T.low), ord(T.high), stringNormalizer)
  except ValueError:
    const typeName = typetraits.name(T)
    r.raiseUnexpectedValue("Invalid value for '" & typeName & "'")

func strictNormalize(s: string): string =  # Match enum value exactly
  s

proc parseEnum[T](
    r: var JsonReader, value: var T, allowNumericRepr: static[bool] = false,
    stringNormalizer: static[proc(s: string): string] = strictNormalize) {.raises: [IOError, JsonReaderError].} =
  const style = T.enumStyle
  let tok = r.lexer.tok
  case tok
  of tkString:
    r.parseStringEnum(value, stringNormalizer)
  of tkInt:
    when allowNumericRepr:
      case style
      of EnumStyle.Numeric:
        if not value.checkedEnumAssign(r.lexer.absIntVal):
          const typeName = typetraits.name(T)
          r.raiseUnexpectedValue("Out of range for '" & typeName & "'")
      of EnumStyle.AssociatedStrings:
        r.raiseUnexpectedToken etEnumString
    else:
      r.raiseUnexpectedToken etEnumString
  else:
    case style
    of EnumStyle.Numeric:
      when allowNumericRepr:
        r.raiseUnexpectedToken etEnumAny
      else:
        r.raiseUnexpectedToken etEnumString
    of EnumStyle.AssociatedStrings:
      r.raiseUnexpectedToken etEnumString

proc readRecordValue*[T](r: var JsonReader, value: var T)
                        {.raises: [SerializationError, IOError].} =
  type
    ReaderType {.used.} = type r
    T = type value

  r.lexer.skipToken tkCurlyLe

  when T.totalSerializedFields > 0:
    let
      fieldsTable = T.fieldReadersTable(ReaderType)

    const
      expectedFields = T.expectedFieldsBitmask

    var
      encounteredFields: typeof(expectedFields)
      mostLikelyNextField = 0

    while true:
      # Have the assignment parsed of the AVP
      if r.lexer.lazyTok == tkQuoted:
        r.lexer.accept
      if r.lexer.lazyTok != tkString:
        break

      when T is tuple:
        let fieldIdx = mostLikelyNextField
        mostLikelyNextField += 1
      else:
        let fieldIdx = findFieldIdx(fieldsTable[],
                                    r.lexer.strVal,
                                    mostLikelyNextField)
      if fieldIdx != -1:
        let reader = fieldsTable[][fieldIdx].reader
        r.lexer.next()
        r.lexer.skipToken tkColon
        reader(value, r)
        encounteredFields.setBitInArray(fieldIdx)
      elif r.allowUnknownFields:
        r.lexer.next()
        r.lexer.skipToken tkColon
        r.lexer.skipSingleJsValue()
      else:
        const typeName = typetraits.name(T)
        r.raiseUnexpectedField(r.lexer.strVal, cstring typeName)

      if r.lexer.lazyTok == tkComma:
        r.lexer.next()
      else:
        break

    if r.requireAllFields and
      not expectedFields.isBitwiseSubsetOf(encounteredFields):
      const typeName = typetraits.name(T)
      r.raiseIncompleteObject(typeName)

  r.lexer.accept
  r.lexer.skipToken tkCurlyRi

proc readValue*[T](r: var JsonReader, value: var T)
                  {.gcsafe, raises: [SerializationError, IOError].} =
  ## Master filed/object parser. This function relies on customised sub-mixins for particular
  ## object types.
  ##
  ## Customised readValue() examples:
  ## ::
  ##     type
  ##       FancyInt = distinct int
  ##       FancyUInt = distinct uint
  ##
  ##     proc readValue(reader: var JsonReader, value: var FancyInt) =
  ##       ## Refer to another readValue() instance
  ##       value = reader.readValue(int).FancyInt
  ##
  ##     proc readValue(reader: var JsonReader, value: var FancyUInt) =
  ##       ## Provide a full custum version of a readValue() instance
  ##       if reader.lexer.lazyTok == tkNumeric:
  ##         # lazyTok: Check token before the value is available
  ##         var accu: FancyUInt
  ##         # custom parser (the directive `customIntValueIt()` is a
  ##         # convenience wrapper around `customIntHandler()`.)
  ##         reader.lexer.customIntValueIt:
  ##           accu = accu * 10 + it.u256
  ##         value = accu
  ##       elif reader.lexer.lazyTok == tkQuoted:
  ##         var accu = string
  ##         # The following is really for demo only (inefficient,
  ##         # lacks hex encoding)
  ##         reader.lexer.customTextValueIt:
  ##           accu &= it
  ##         value = accu.parseUInt.FancyUInt
  ##       ...
  ##       # prepare next parser cycle
  ##       reader.lexer.next
  ##
  mixin readValue

  when value is (object or tuple):
    let tok {.used.} = r.lexer.lazyTok
  else:
    let tok {.used.} = r.lexer.tok # resove lazy token

  when value is JsonString:
    r.captureSingleJsValue(string value)

  elif value is JsonNode:
    value = r.parseJsonNode()

  elif value is string:
    r.lexer.requireToken tkString
    value = r.lexer.strVal
    r.lexer.next()

  elif value is seq[char]:
    r.lexer.requireToken tkString
    value.setLen(r.lexer.strVal.len)
    for i in 0..<r.lexer.strVal.len:
      value[i] = r.lexer.strVal[i]
    r.lexer.next()

  elif isCharArray(value):
    r.lexer.requireToken tkString
    if r.lexer.strVal.len != value.len:
      # Raise tkString because we expected a `"` earlier
      r.raiseUnexpectedToken(etString)
    for i in 0..<value.len:
      value[i] = r.lexer.strVal[i]
    r.lexer.next()

  elif value is bool:
    case tok
    of tkTrue: value = true
    of tkFalse: value = false
    else: r.raiseUnexpectedToken etBool
    r.lexer.next()

  elif value is ref|ptr:
    when compiles(isNotNilCheck(value)):
      allocPtr value
      value[] = readValue(r, type(value[]))
    else:
      if tok == tkNull:
        value = nil
        r.lexer.next()
      else:
        allocPtr value
        value[] = readValue(r, type(value[]))

  elif value is enum:
    r.parseEnum(value)
    r.lexer.next()

  elif value is SomeSignedInt:
    type TargetType = type(value)
    let
      isNegative = tok == tkNegativeInt
      maxValidAbsValue: BiggestUint =
        if isNegative:
          TargetType.high.BiggestUint + 1
        else:
          TargetType.high.BiggestUint

    if r.lexer.absIntVal > maxValidAbsValue:
      r.raiseIntOverflow(r.lexer.absIntVal, isNegative)

    case tok
    of tkInt:
      value = TargetType(r.lexer.absIntVal)
    of tkNegativeInt:
      if r.lexer.absIntVal == maxValidAbsValue:
        # We must handle this as a special case because it would be illegal
        # to convert a value like 128 to int8 before negating it. The max
        # int8 value is 127 (while the minimum is -128).
        value = low(TargetType)
      else:
        value = -TargetType(r.lexer.absIntVal)
    else:
      r.raiseUnexpectedToken etInt
    r.lexer.next()

  elif value is SomeUnsignedInt:
    type TargetType = type(value)

    if r.lexer.absIntVal > TargetType.high.BiggestUint:
      r.raiseIntOverflow(r.lexer.absIntVal, isNegative = false)

    case tok
    of tkInt:
      value = TargetType(r.lexer.absIntVal)
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
    r.lexer.skipToken tkBracketLe
    if r.lexer.tok != tkBracketRi:
      while true:
        let lastPos = value.len
        value.setLen(lastPos + 1)
        readValue(r, value[lastPos])
        if r.lexer.tok != tkComma: break
        r.lexer.next()
    r.lexer.skipToken tkBracketRi

  elif value is array:
    r.lexer.skipToken tkBracketLe
    for i in low(value) ..< high(value):
      # TODO: dont's ask. this makes the code compile
      if false: value[i] = value[i]
      readValue(r, value[i])
      r.lexer.skipToken tkComma
    readValue(r, value[high(value)])
    r.lexer.skipToken tkBracketRi

  elif value is (object or tuple):
    mixin flavorUsesAutomaticObjectSerialization

    type Flavor = JsonReader.Flavor
    const isAutomatic =
      flavorUsesAutomaticObjectSerialization(Flavor)

    when not isAutomatic:
      const typeName = typetraits.name(T)
      {.error: "Please override readValue for the " & typeName & " type (or import the module where the override is provided)".}

    readRecordValue(r, value)
  else:
    const typeName = typetraits.name(T)
    {.error: "Failed to convert to JSON an unsupported type: " & typeName.}

iterator readObjectFields*(r: var JsonReader): string {.
    raises: [IOError, SerializationError].} =
  for key in readObjectFields(r, string):
    yield key

template configureJsonDeserialization*(
    T: type[enum], allowNumericRepr: static[bool] = false,
    stringNormalizer: static[proc(s: string): string] = strictNormalize) =
  proc readValue*(r: var JsonReader, value: var T) {.
      raises: [IOError, SerializationError].} =
    static: doAssert not allowNumericRepr or enumStyle(T) == EnumStyle.Numeric
    r.parseEnum(value, allowNumericRepr, stringNormalizer)

{.pop.}
