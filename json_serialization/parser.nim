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
  ./reader_desc,
  ./lexer

from json import JsonNode, JsonNodeKind, escapeJson, parseJson

export
  reader_desc

{.push gcsafe, raises: [].}

type
  NumberPart* = enum
    SignPart
    IntegerPart
    FractionPart
    ExpSignPart
    ExponentPart

  CustomNumberHandler* = ##\
    ## Custom number parser, result values need to be captured
    proc(part: NumberPart; dgt: int) {.gcsafe, raises: [].}

  CustomIntHandler* = ##\
    ## Custom integer parser, result values need to be captured
    proc(dgt: int) {.gcsafe, raises: [].}

  CustomStringHandler* = ##\
    ## Custom text or binary parser, result values need to be captured.
    proc(b: char) {.gcsafe, raises: [].}

# ------------------------------------------------------------------------------
# Private helpers
# ------------------------------------------------------------------------------

template raiseParserError(r: var JsonReader) =
  r.raiseUnexpectedValue($r.lex.err)

template raiseParserError(r: var JsonReader, err: JsonErrorKind) =
  r.raiseUnexpectedValue($err)

# ------------------------------------------------------------------------------
# Public helpers
# ------------------------------------------------------------------------------

template checkError*(r: var JsonReader) =
  if r.lex.isErr:
    r.raiseParserError()

proc tokKind*(r: var JsonReader): JsonValueKind
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  result = r.lex.tokKind
  r.checkError

# ------------------------------------------------------------------------------
# Custom iterators
# ------------------------------------------------------------------------------

proc customIntHandler*(r: var JsonReader; handler: CustomIntHandler)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  ## Apply the `handler` argument function for parsing only integer part
  ## of JsonNumber
  # TODO: remove temporary token
  if r.tokKind != JsonValueKind.Number:
    r.raiseParserError(errNumberExpected)
  var val: JsonNumber[string]
  r.lex.scanNumber(val)
  r.checkError
  if val.isFloat:
    r.raiseParserError(errCustomIntExpected)
  for c in val.integer:
    handler(ord(c) - ord('0'))

proc customNumberHandler*(r: var JsonReader; handler: CustomNumberHandler)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  ## Apply the `handler` argument function for parsing complete JsonNumber
  # TODO: remove temporary token
  if r.tokKind != JsonValueKind.Number:
    r.raiseParserError(errNumberExpected)
  var val: JsonNumber[string]
  r.lex.scanNumber(val)
  r.checkError
  handler(SignPart, val.sign.toInt)
  for c in val.integer:
    handler(IntegerPart, ord(c) - ord('0'))
  for c in val.fraction:
    handler(FractionPart, ord(c) - ord('0'))
  handler(ExpSignPart, val.expSign.toInt)
  for c in val.exponent:
    handler(ExponentPart, ord(c) - ord('0'))

proc customStringHandler*(r: var JsonReader; limit: int; handler: CustomStringHandler)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  ## Apply the `handler` argument function for parsing a String type
  ## value.
  # TODO: remove temporary token
  if r.tokKind != JsonValueKind.String:
    r.raiseParserError(errStringExpected)
  var val: string
  r.lex.scanString(val, limit)
  r.checkError
  for c in val:
    handler(c)

template customIntValueIt*(r: var JsonReader; body: untyped) =
  ## Convenience wrapper around `customIntHandler()` for parsing integers.
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## digit processing can be exited with `return`.
  var handler: CustomIntHandler =
    proc(digit: int) =
      let it {.inject.} = digit
      body
  r.customIntHandler(handler)

template customNumberValueIt*(r: var JsonReader; body: untyped) =
  ## Convenience wrapper around `customIntHandler()` for parsing numbers.
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## digit processing can be exited with `return`.
  let handler: CustomNumberHandler =
    proc(part: NumberPart, digit: int) =
      let it {.inject.} = digit
      let part {.inject.} = part
      body
  r.customNumberHandler(handler)

# !!!: don't change limit from untyped to int, it will trigger Nim bug
# the second overloaded customStringValueIt will fail to compile
template customStringValueIt*(r: var JsonReader; limit: untyped; body: untyped) =
  ## Convenience wrapper around `customStringHandler()` for parsing a text
  ## terminating with a double quote character '"'.
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## character processing can be exited with `return`.
  let handler: CustomStringHandler =
    proc(c: char) =
      let it {.inject.} = c
      body
  r.customStringHandler(limit, handler)

template customStringValueIt*(r: var JsonReader; body: untyped) =
  ## Convenience wrapper around `customStringHandler()` for parsing a text
  ## terminating with a double quote character '"'.
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## character processing can be exited with `return`.
  let handler: CustomStringHandler =
    proc(c: char) =
      let it {.inject.} = c
      body
  r.customStringHandler(r.lex.conf.stringLengthLimit, handler)

# ------------------------------------------------------------------------------
# Public parsers
# ------------------------------------------------------------------------------

proc parseString*(r: var JsonReader, limit: int): string
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.String:
    r.raiseParserError(errStringExpected)
  r.lex.scanString(result, limit)
  r.checkError

proc parseString*(r: var JsonReader): string
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  r.parseString(r.lex.conf.stringLengthLimit)

proc parseBool*(r: var JsonReader): bool
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.Bool:
    r.raiseParserError(errBoolExpected)
  result = r.lex.scanBool()
  r.checkError

proc parseNull*(r: var JsonReader)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.Null:
    r.raiseParserError(errNullExpected)
  r.lex.scanNull()
  r.checkError

proc parseNumberImpl[F,T](r: var JsonReader[F]): JsonNumber[T]
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.Number:
    r.raiseParserError(errNumberExpected)
  r.lex.scanNumber(result)
  r.checkError

template parseNumber*(r: var JsonReader, T: type): auto =
  ## workaround Nim inablity to instantiate result type
  ## when one the argument is generic type and the other
  ## is a typedesc
  type F = typeof(r)
  parseNumberImpl[F.Flavor, T](r)

proc parseNumber*(r: var JsonReader, val: var JsonNumber)
                   {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.Number:
    r.raiseParserError(errNumberExpected)
  r.lex.scanNumber(val)
  r.checkError

proc toInt*(r: var JsonReader, val: JsonNumber, T: type SomeSignedInt, portable: bool): T
      {.gcsafe, raises: [JsonReaderError].}=
  if val.sign == JsonSign.Neg:
    if val.integer.uint64 > T.high.uint64 + 1:
      raiseIntOverflow(r, val.integer, true)
    elif val.integer == T.high.uint64 + 1:
      result = T.low
    else:
      result = -T(val.integer)
  else:
    if val.integer > T.high.uint64:
      raiseIntOverflow(r, val.integer, false)
    result = T(val.integer)

  if portable and result.int64 > maxPortableInt.int64:
    raiseIntOverflow(r, result.BiggestUInt, false)
  if portable and result.int64 < minPortableInt.int64:
    raiseIntOverflow(r, result.BiggestUInt, true)

proc toInt*(r: var JsonReader, val: JsonNumber, T: type SomeUnsignedInt, portable: bool): T
      {.gcsafe, raises: [IOError, JsonReaderError].}=
  if val.sign == JsonSign.Neg:
    raiseUnexpectedToken(r, etInt)
  if val.integer > T.high.uint64:
    raiseIntOverflow(r, val.integer, false)

  if portable and val.integer > maxPortableInt.uint64:
    raiseIntOverflow(r, val.integer.BiggestUInt, false)

  T(val.integer)

proc parseInt*(r: var JsonReader, T: type SomeInteger, portable: bool = false): T
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.Number:
    r.raiseParserError(errNumberExpected)
  var val: JsonNumber[uint64]
  r.lex.scanNumber(val)
  r.checkError
  if val.isFloat:
    r.raiseParserError(errInvalidInt)
  r.toInt(val, T, portable)

proc toFloat*(r: var JsonReader, val: JsonNumber, T: type SomeFloat): T
      {.gcsafe, raises: [JsonReaderError].}=
  const
    powersOfTen = [1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
                   1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
                   1e20, 1e21, 1e22] # TODO: this table should be much larger
                                     # The largest JSON number value is 1E308

  result = T(val.integer)

  var fraction = T(0.1)
  for c in val.fraction:
    result += fraction * T(ord(c) - ord('0'))
    fraction *= T(0.1)

  if val.sign == JsonSign.Neg:
    result = result * T(-1.0)

  if val.exponent >= uint64(len(powersOfTen)):
    r.raiseParserError(errExponentTooLarge)

  if val.expSign == JsonSign.Neg:
    result = result / powersOfTen[val.exponent]
  else:
    result = result * powersOfTen[val.exponent]

proc parseFloat*(r: var JsonReader, T: type SomeFloat): T
      {.gcsafe, raises: [IOError, JsonReaderError].} =
  if r.tokKind != JsonValueKind.Number:
    r.raiseParserError(errNumberExpected)
  var val: JsonNumber[uint64]
  r.lex.scanNumber(val)
  r.checkError
  r.toFloat(val, T)

proc parseAsString*(r: var JsonReader, val: var string)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  case r.tokKind
  of JsonValueKind.String:
    escapeJson(r.parseString(), val)
  of JsonValueKind.Number:
    r.lex.scanNumber(val)
    r.checkError
  of JsonValueKind.Object:
    parseObjectImpl(r.lex, false):
      # initial action
      val.add '{'
    do: # closing action
      val.add '}'
    do: # comma action
      val.add ','
    do: # key action
      escapeJson(r.parseString(), val)
    do: # value action
      val.add ':'
      r.parseAsString(val)
    do: # error action
      r.raiseParserError()
  of JsonValueKind.Array:
    parseArrayImpl(r.lex, idx):
      # initial action
      val.add '['
    do: # closing action
      val.add ']'
    do: # comma action
      val.add ','
    do: # value action
      r.parseAsString(val)
    do: # error action
      r.raiseParserError()
  of JsonValueKind.Bool:
    if r.parseBool():
      val.add "true"
    else:
      val.add "false"
  of JsonValueKind.Null:
    r.parseNull()
    val.add "null"

proc parseAsString*(r: var JsonReader): JsonString
      {.gcsafe, raises: [IOError, JsonReaderError].} =
  var val: string
  r.parseAsString(val)
  val.JsonString

proc parseValueImpl[F,T](r: var JsonReader[F]): JsonValueRef[T]
      {.gcsafe, raises: [IOError, JsonReaderError].} =
  r.lex.scanValue(result)
  r.checkError

template parseValue*(r: var JsonReader, T: type): auto =
  ## workaround Nim inablity to instantiate result type
  ## when one the argument is generic type and the other
  ## is a typedesc
  type F = typeof(r)
  parseValueImpl[F.Flavor, T](r)

proc parseValue*(r: var JsonReader, val: var JsonValueRef)
                  {.gcsafe, raises: [IOError, JsonReaderError].} =
  r.lex.scanValue(val)
  r.checkError

template parseArray*(r: var JsonReader; body: untyped) =
  if r.tokKind != JsonValueKind.Array:
    r.raiseParserError(errBracketLeExpected)
  parseArrayImpl(r.lex, idx): discard # initial action
  do: discard # closing action
  do: discard # comma action
  do: body    # value action
  do: r.raiseParserError() # error action

template parseArray*(r: var JsonReader; idx: untyped; body: untyped) =
  if r.tokKind != JsonValueKind.Array:
    r.raiseParserError(errBracketLeExpected)
  parseArrayImpl(r.lex, idx): discard # initial action
  do: discard # closing action
  do: discard # comma action
  do: body    # value action
  do: r.raiseParserError() # error action

template parseObject*(r: var JsonReader, key: untyped, body: untyped) =
  mixin flavorSkipNullFields
  type
    Reader = typeof r
    Flavor = Reader.Flavor
  const skipNullFields = flavorSkipNullFields(typeof Flavor)

  if r.tokKind != JsonValueKind.Object:
    r.raiseParserError(errCurlyLeExpected)
  parseObjectImpl(r.lex, skipNullFields): discard # initial action
  do: discard # closing action
  do: discard # comma action
  do: # key action
    let key {.inject.} = r.parseString()
  do: # value action
    body
  do: # error action
    r.raiseParserError()

template parseObjectWithoutSkip*(r: var JsonReader, key: untyped, body: untyped) =
  if r.tokKind != JsonValueKind.Object:
    r.raiseParserError(errCurlyLeExpected)
  parseObjectImpl(r.lex, false): discard # initial action
  do: discard # closing action
  do: discard # comma action
  do: # key action
    let key {.inject.} = r.parseString()
  do: # value action
    body
  do: # error action
    r.raiseParserError()

template parseObjectSkipNullFields*(r: var JsonReader, key: untyped, body: untyped) =
  if r.tokKind != JsonValueKind.Object:
    r.raiseParserError(errCurlyLeExpected)
  parseObjectImpl(r.lex, true): discard # initial action
  do: discard # closing action
  do: discard # comma action
  do: # key action
    let key {.inject.} = r.parseString()
  do: # value action
    body
  do: # error action
    r.raiseParserError()

template parseObjectCustomKey*(r: var JsonReader, keyAction: untyped, body: untyped) =
  mixin flavorSkipNullFields
  type
    Reader = typeof r
    Flavor = Reader.Flavor
  const skipNullFields = flavorSkipNullFields(Flavor)

  if r.tokKind != JsonValueKind.Object:
    r.raiseParserError(errCurlyLeExpected)
  parseObjectImpl(r.lex, skipNullFields): discard # initial action
  do: discard # closing action
  do: discard # comma action
  do: # key action
    keyAction
  do: # value action
    body
  do: # error action
    r.raiseParserError()

# ------------------------------------------------------------------------------
# Parse to stdlib's JsonNode
# ------------------------------------------------------------------------------

proc parseJsonNode*(r: var JsonReader): JsonNode
                 {.gcsafe, raises: [IOError, JsonReaderError].}

proc readJsonNodeField(r: var JsonReader, field: var JsonNode)
                  {.gcsafe, raises: [IOError, JsonReaderError].} =
  if field.isNil.not:
    r.raiseUnexpectedValue("Unexpected duplicated field name")
  field = r.parseJsonNode()

proc parseJsonNode(r: var JsonReader): JsonNode =
  case r.tokKind
  of JsonValueKind.String:
    result = JsonNode(kind: JString, str: r.parseString())
  of JsonValueKind.Number:
    var val: string
    r.lex.scanNumber(val)
    r.checkError
    when (NimMajor, NimMinor) > (1,6):
      try:
        # Cannot access `newJRawNumber` directly, because it's not exported.
        # But this should produce either JInt, JFloat, or JString/Raw
        result = parseJson(val)
      except ValueError as exc:
        r.raiseUnexpectedValue(exc.msg)
      except OSError as exc:
        raiseAssert "parseJson here should not raise OSError exception: " & exc.msg
    else:
      try:
        result = parseJson(val)
      except Exception as exc:
        r.raiseUnexpectedValue(exc.msg)
  of JsonValueKind.Object:
    result = JsonNode(kind: JObject)
    parseObjectImpl(r.lex, false): discard # initial action
    do: discard # closing action
    do: discard # comma action
    do: # key action
      let key = r.parseString()
    do: # value action
      try:
        r.readJsonNodeField(result.fields.mgetOrPut(key, nil))
      except KeyError:
        raiseAssert "mgetOrPut should never raise a KeyError"
    do: # error action
      r.raiseParserError()
  of JsonValueKind.Array:
    result = JsonNode(kind: JArray)
    parseArrayImpl(r.lex, idx): discard # initial action
    do: discard # closing action
    do: discard # comma action
    do: # value action
      result.elems.add r.parseJsonNode()
    do: # error action
      r.raiseParserError()
  of JsonValueKind.Bool:
    result = JsonNode(kind: JBool, bval: r.parseBool())
  of JsonValueKind.Null:
    r.parseNull()
    result = JsonNode(kind: JNull)

# ------------------------------------------------------------------------------
# Misc helpers
# ------------------------------------------------------------------------------

proc skipSingleJsValue*(lex: var JsonLexer) {.raises: [IOError, JsonReaderError].}  =
  var val: JsonVoid
  lex.scanValue(val)
  if lex.isErr:
    lex.raiseUnexpectedValue($lex.err)

template skipSingleJsValue*(r: var JsonReader) =
  skipSingleJsValue(r.lex)

{.pop.}
