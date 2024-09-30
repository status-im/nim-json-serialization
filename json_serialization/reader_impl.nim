# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.experimental: "notnil".}

import
  std/[enumutils, tables, macros, strformat, typetraits],
  stew/[enums, objects],
  faststreams/inputs,
  serialization/[object_serialization, errors],
  "."/[format, types, lexer, parser, reader_desc]

from json import JsonNode

export
  enumutils, inputs, format, types, errors, parser, reader_desc

{.push gcsafe, raises: [].}

# ------------------------------------------------------------------------------
# Private helpers
# ------------------------------------------------------------------------------

func allowUnknownFields(r: JsonReader): bool =
  JsonReaderFlag.allowUnknownFields in r.lex.flags

func requireAllFields(r: JsonReader): bool =
  JsonReaderFlag.requireAllFields in r.lex.flags

func allocPtr[T](p: var ptr T) =
  p = create(T)

func allocPtr[T](p: var ref T) =
  p = new(T)

func isNotNilCheck[T](x: ref T not nil) {.compileTime.} = discard
func isNotNilCheck[T](x: ptr T not nil) {.compileTime.} = discard

func setBitInWord(x: var uint, bit: int) {.inline.} =
  let mask = uint(1) shl bit
  x = x or mask

const bitsPerWord = sizeof(uint) * 8

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

proc parseStringEnum[T](
    r: var JsonReader, value: var T,
    stringNormalizer: static[proc(s: string): string])
      {.raises: [IOError, JsonReaderError].} =
  try:
    value = genEnumCaseStmt(
      T, r.parseString(),
      default = nil, ord(T.low), ord(T.high), stringNormalizer)
  except ValueError:
    const typeName = typetraits.name(T)
    r.raiseUnexpectedValue("Invalid value for '" & typeName & "'")

func strictNormalize(s: string): string =  # Match enum value exactly
  s

proc parseEnum[T](
    r: var JsonReader, value: var T, allowNumericRepr: static[bool] = false,
    stringNormalizer: static[proc(s: string): string] = strictNormalize)
      {.raises: [IOError, JsonReaderError].} =
  const style = T.enumStyle
  case r.tokKind
  of JsonValueKind.String:
    r.parseStringEnum(value, stringNormalizer)
  of JsonValueKind.Number:
    when allowNumericRepr:
      case style
      of EnumStyle.Numeric:
        if not value.checkedEnumAssign(r.parseInt(int)):
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

# ------------------------------------------------------------------------------
# Public iterators
# ------------------------------------------------------------------------------

iterator readArray*(r: var JsonReader, ElemType: typedesc): ElemType
          {.raises: [IOError, SerializationError].} =
  mixin readValue

  r.parseArray:
    var res: ElemType
    readValue(r, res)
    yield res

iterator readObjectFields*(r: var JsonReader,
                           KeyType: type): KeyType
                             {.raises: [IOError, SerializationError].} =
  mixin readValue

  r.parseObjectCustomKey:
    var key: KeyType
    readValue(r, key)
  do:
    yield key

iterator readObject*(r: var JsonReader,
                     KeyType: type,
                     ValueType: type): (KeyType, ValueType)
                       {.raises: [IOError, SerializationError].} =
  mixin readValue

  for fieldName in readObjectFields(r, KeyType):
    var value: ValueType
    readValue(r, value)
    yield (fieldName, value)

# ------------------------------------------------------------------------------
# Public functions
# ------------------------------------------------------------------------------

func isFieldExpected*(T: type): bool {.compileTime.} =
  T isnot Option

func totalExpectedFields*(T: type): int {.compileTime.} =
  mixin isFieldExpected,
        enumAllSerializedFields

  enumAllSerializedFields(T):
    if isFieldExpected(FieldType):
      inc result

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

proc readRecordValue*[T](r: var JsonReader, value: var T)
                        {.raises: [SerializationError, IOError].} =
  type
    ReaderType {.used.} = type r
    T = type value

  const someCode = T.totalSerializedFields > 0

  when someCode:
    const
      fieldsTable = T.fieldReadersTable(ReaderType)
      expectedFields = T.expectedFieldsBitmask

    var
      encounteredFields: typeof(expectedFields)
      mostLikelyNextField = 0

  r.parseObjectCustomKey:
    when someCode:
      let key = r.parseString()
      when T is tuple:
        let fieldIdx = mostLikelyNextField
        mostLikelyNextField += 1
        discard key
      else:
        let fieldIdx = findFieldIdx(fieldsTable,
                                    key,
                                    mostLikelyNextField)
  do:
    when someCode:
      if fieldIdx != -1:
        let reader = fieldsTable[fieldIdx].reader
        reader(value, r)
        encounteredFields.setBitInArray(fieldIdx)
      elif r.allowUnknownFields:
        r.skipSingleJsValue()
      else:
        const typeName = typetraits.name(T)
        r.raiseUnexpectedField(key, cstring typeName)

  when someCode:
    if r.requireAllFields and
      not expectedFields.isBitwiseSubsetOf(encounteredFields):
      const typeName = typetraits.name(T)
      r.raiseIncompleteObject(typeName)

proc readValue*[T](r: var JsonReader, value: var T)
                  {.gcsafe, raises: [SerializationError, IOError].} =
  ## Master field/object parser. This function relies on
  ## customised sub-mixins for particular object types.
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
  mixin readValue

  when value is JsonString:
    value = r.parseAsString()

  elif value is JsonNode:
    value = r.parseJsonNode()

  elif value is JsonNumber:
    r.parseNumber(value)

  elif value is JsonVoid:
    r.skipSingleJsValue()

  elif value is JsonValueRef:
    r.parseValue(value)

  elif value is string:
    value = r.parseString()

  elif value is seq[char]:
    let val = r.parseString()
    value.setLen(val.len)
    for i in 0..<val.len:
      value[i] = val[i]

  elif isCharArray(value):
    let val = r.parseString()
    if val.len != value.len:
      # Raise tkString because we expected a `"` earlier
      r.raiseUnexpectedToken(etString)
    for i in 0..<value.len:
      value[i] = val[i]

  elif value is bool:
    value = r.parseBool()

  elif value is ref|ptr:
    when compiles(isNotNilCheck(value)):
      allocPtr value
      value[] = readValue(r, type(value[]))
    else:
      if r.tokKind == JsonValueKind.Null:
        value = nil
        r.parseNull()
      else:
        allocPtr value
        value[] = readValue(r, type(value[]))

  elif value is enum:
    r.parseEnum(value)

  elif value is SomeInteger:
    value = r.parseInt(typeof value,
      JsonReaderFlag.portableInt in r.lex.flags)

  elif value is SomeFloat:
    let val = r.parseNumber(uint64)
    if val.isFloat:
      value = r.toFloat(val, typeof value)
    else:
      value = T(val.integer)

  elif value is seq:
    r.parseArray:
      let lastPos = value.len
      value.setLen(lastPos + 1)
      readValue(r, value[lastPos])

  elif value is array:
    type IDX = typeof low(value)
    r.parseArray(idx):
      let i = IDX(idx + low(value).int)
      if i <= high(value):
        # TODO: dont's ask. this makes the code compile
        if false: value[i] = value[i]
        readValue(r, value[i])

  elif value is (object or tuple):
    mixin flavorUsesAutomaticObjectSerialization

    type Flavor = JsonReader.Flavor
    const isAutomatic =
      flavorUsesAutomaticObjectSerialization(Flavor)

    when not isAutomatic:
      const
        flavor =
          "JsonReader[" & typetraits.name(typeof(r).Flavor) & "], " &
          typetraits.name(T)
      {.error:
        "Missing Json serialization import or implementation for readValue(" &
        flavor & ")".}

    readRecordValue(r, value)
  else:
    const typeName = typetraits.name(T)
    {.error: "Failed to convert to JSON an unsupported type: " &
      typeName.}

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
