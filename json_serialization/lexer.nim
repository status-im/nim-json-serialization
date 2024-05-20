# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[json, unicode],
  faststreams/inputs,
  types

export
  inputs, types

type
  JsonErrorKind* = enum
    errNone                 = "no error"
    errHexCharExpected      = "hex char expected (part of escape sequence)"
    errStringExpected       = "string expected"
    errColonExpected        = "':' expected"
    errCommaExpected        = "',' expected"
    errBracketRiExpected    = "']' expected"
    errCurlyRiExpected      = "'}' expected"
    errBracketLeExpected    = "'[' expected"
    errCurlyLeExpected      = "'{' expected"
    errQuoteExpected        = "'\"' or \"'\" expected"
    errNumberExpected       = "number expected"
    errExponentTooLarge     = "exponent too large"
    errUnexpectedEof        = "unexpected end of file"
    errCommentExpected      = "comment expected"
    errBoolExpected         = "boolean value expected"
    errNullExpected         = "null value expected"
    errCommentNotAllowed    = "comment not allowed, please set 'allowComments' flag"
    errTrailingComma        = "trailing comma not allowed, please set 'trailingComma' flag"
    errOrphanSurrogate      = "unicode surrogates must be followed by another unicode character"
    errNonPortableInt       = "number is outside the range of portable values"
    errCustomIntExpected    = "not a customised integer"
    errCustomBlobExpected   = "not a customised quoted blob"
    errLeadingZero          = "leading zero is not allowed in integer"
    errU64Overflow          = "uint64 overflow detected"
    errIntDigitLimit        = "max number of integer digits reached"
    errFracDigitLimit       = "max number of fraction digits reached"
    errExpDigitLimit        = "max number of exponent digits reached"
    errInvalidBool          = "invalid boolean value"
    errInvalidNull          = "invalid null value"
    errStringLengthLimit    = "max number of string chars reached, please set `stringLengthLimit` to overrride"
    errEscapeHex            = "please set `escapeHex` flag to allow \\xHH escape mode"
    errRelaxedEscape        = "unsupported escape char, set `relaxedEscape` flag to override"
    errLeadingFraction      = "fraction number must be preceded by number, set `leadingFraction` to override"
    errUnknownChar          = "unknown character"
    errNestedDepthLimit     = "max depth of nested structure reached, please set `nestedDepthLimit` to override"
    errArrayElementsLimit   = "max number of array elements reached, please set `arrayElementsLimit` to override"
    errObjectMembersLimit   = "max number of object members reached, please set `objectMembersLimit` to override"
    errMissingFirstElement  = "first array/table element missing"
    errEmptyFraction        = "fraction number should have at least one fractional digit"
    errIntPosSign           = "integer with positive sign is not allowed, please set `integerPositiveSign` to override"
    errValueExpected        = "json value expected, got comma"
    errEscapeControlChar    = "control character x00-x1F must be escaped"
    errInvalidInt           = "invalid integer value"

  JsonLexer* = object
    stream*: InputStream
    err*: JsonErrorKind
    flags*: JsonReaderFlags
    conf*: JsonReaderConf

    line*: int
    lineStartPos: int
    tokenStart: int
    depthLimit: int

{.push gcsafe, raises: [].}

# ------------------------------------------------------------------------------
# Private helpers
# ------------------------------------------------------------------------------

template error(error: JsonErrorKind) {.dirty.} =
  lex.err = error
  return

template error(error: JsonErrorKind, retVal: int) {.dirty.} =
  lex.err = error
  return retVal

template error(lex: JsonLexer, error: JsonErrorKind, action: untyped) {.dirty.} =
  lex.err = error
  action

template ok(lex: JsonLexer): bool =
  lex.err == errNone

template readable(lex: JsonLexer): bool =
  inputs.readable(lex.stream)

template peek(lex: JsonLexer): char =
  char inputs.peek(lex.stream)

template read(lex: JsonLexer): char =
  char inputs.read(lex.stream)

template advance(lex: JsonLexer) =
  inputs.advance(lex.stream)

template checkForUnexpectedEof(lex: JsonLexer) =
  if not lex.readable:
    error errUnexpectedEof

template requireNextChar(lex: JsonLexer): char =
  lex.checkForUnexpectedEof()
  lex.read()

template enterNestedStructure(lex: JsonLexer, action: untyped) {.dirty.} =
  bind errNestedDepthLimit
  inc lex.depthLimit
  if lex.conf.nestedDepthLimit > 0 and
     lex.depthLimit > lex.conf.nestedDepthLimit:
    lex.err = errNestedDepthLimit
    action

template exitNestedStructure(lex: JsonLexer) =
  dec lex.depthLimit

proc handleLF(lex: var JsonLexer) =
  lex.advance
  lex.line += 1
  lex.lineStartPos = lex.stream.pos
  lex.tokenStart = lex.stream.pos

proc isDigit(c: char): bool =
  return (c >= '0' and c <= '9')

template eatDigitAndPeek(body: untyped): char =
  lex.advance
  if not lex.readable:
    body
  lex.peek()

proc skipWhitespace(lex: var JsonLexer)
    {.gcsafe, raises: [IOError].} =

  template handleCR =
    # Beware: this is a template, because the return
    # statement has to exit `skipWhitespace`.
    lex.advance
    if not lex.readable: return
    if lex.peek() == '\n': lex.advance
    lex.line += 1
    lex.lineStartPos = lex.stream.pos
    lex.tokenStart = lex.stream.pos

  template handleComment =
    # Beware: this is a template, because the return
    # statement has to exit `skipWhitespace`.
    lex.advance
    lex.checkForUnexpectedEof()
    case lex.peek()
    of '/':
      lex.advance
      while true:
        if not lex.readable: return
        case lex.peek()
        of '\r':
          handleCR()
          break
        of '\n':
          lex.handleLF()
          break
        else:
          lex.advance
    of '*':
      lex.advance
      while true:
        if not lex.readable: return
        case lex.peek()
        of '\r':
          handleCR()
        of '\n':
          lex.handleLF()
        of '*':
          lex.advance
          lex.checkForUnexpectedEof()
          if lex.peek() == '/':
            lex.advance
            break
        else:
          lex.advance
    else:
      error errCommentExpected

  while lex.readable:
    case lex.peek()
    of '/':
      lex.tokenStart = lex.stream.pos
      if JsonReaderFlag.allowComments in lex.flags:
        handleComment()
      else:
        error errCommentNotAllowed
    of ' ', '\t':
      lex.advance
    of '\r':
      handleCR()
    of '\n':
      lex.handleLF()
    else:
      break

proc next(lex: var JsonLexer): char {.gcsafe, raises: [IOError].} =
  ## Return the next available char from the stream associate with
  ## the lexer.
  if not lex.readable(): return
  result = lex.read()

func hexCharValue(c: char): int =
  case c
  of '0'..'9': ord(c) - ord('0')
  of 'a'..'f': ord(c) - ord('a') + 10
  of 'A'..'F': ord(c) - ord('A') + 10
  else: -1

proc scanHexRune(lex: var JsonLexer): int
    {.gcsafe, raises: [IOError].} =
  for i in 0..3:
    let hexValue = hexCharValue lex.requireNextChar()
    if hexValue == -1: error errHexCharExpected
    result = (result shl 4) or hexValue

proc scanHex(lex: var JsonLexer): int
    {.gcsafe, raises: [IOError].} =
  result = hexCharValue lex.requireNextChar()
  if result == -1: error errHexCharExpected
  let hex = hexCharValue lex.requireNextChar()
  if hex == -1: error errHexCharExpected
  result = (result shl 4) or hex

template requireMoreNumberChars() =
  if not lex.readable:
    error errNumberExpected

proc scanSign(lex: var JsonLexer): JsonSign
    {.gcsafe, raises: [].} =
  # Returns None, Pos, or Neg
  # If a sign character is present, it must be followed
  # by more characters representing the number. If this
  # is not the case, lex.err = errNumberExpected.
  let c = lex.peek()
  if c == '-':
    lex.advance
    return JsonSign.Neg
  elif c == '+':
    lex.advance
    return JsonSign.Pos

  return JsonSign.None

proc scanSign[T](lex: var JsonLexer, val: var T, onlyNeg = false)
    {.gcsafe, raises: [].} =

  when T isnot (string or JsonVoid or JsonSign):
    {.fatal: "`scanNumber` only accepts `string` or `JsonVoid` or `JsonSign`".}

  let sign = lex.scanSign()

  if onlyNeg and sign == JsonSign.Pos:
    if integerPositiveSign notin lex.flags:
      error errIntPosSign

  if not lex.ok: return

  when T is string:
    if sign == JsonSign.Neg: val.add '-'
    elif sign == JsonSign.Pos: val.add '+'
  elif T is JsonSign:
    val = sign
  elif T is JsonVoid:
    discard

proc scanInt[T](lex: var JsonLexer, val: var T,
                limit: int,
                intPart: bool = true,
                errKind = errIntDigitLimit): int
                {.gcsafe, raises: [IOError].} =
  ## scanInt only accepts `string` or `uint64` or `JsonVoid`
  ## If all goes ok, parsed-value is returned.
  ## On overflow, lex.err = errU64Overflow.
  ## If contains leading zero, lex.err = errLeadingZero.
  ## If exceeds digit numbers, lex.err = errKind.

  var
    first = lex.peek()
    numDigits = 1

  if first.isDigit.not:
    error errNumberExpected, 0

  # Always possible to append `9` is `val` is not larger
  when T is uint64:
    const canAppendDigit9 = (uint64.high - 9) div 10
    val = uint64(ord(first) - ord('0'))
  elif T is string:
    val.add first
  elif T is JsonVoid:
    discard
  else:
    {.fatal: "`scanInt` only accepts `string` or `uint64` or `JsonVoid`".}

  var c = eatDigitAndPeek: return 1

  if first == '0' and c.isDigit and intPart:
    error errLeadingZero, 1

  inc numDigits

  while c.isDigit:
    if numDigits > limit:
      error errKind, numDigits

    # Process next digit unless overflow/maxdigit
    if lex.ok:
      when T is uint64:
        let lsDgt = uint64(ord(c) - ord('0'))
        if canAppendDigit9 < val and
            (uint64.high - lsDgt) div 10 < val:
          val = uint64.high
          error errU64Overflow, numDigits
        else:
          val = val * 10 + lsDgt
      elif T is string:
        val.add c

    # Fetch next digit
    c = eatDigitAndPeek: return numDigits

    inc numDigits

  numDigits

# ------------------------------------------------------------------------------
# Constructors
# ------------------------------------------------------------------------------

proc init*(T: type JsonLexer,
           stream: InputStream,
           flags: JsonReaderFlags = defaultJsonReaderFlags,
           conf: JsonReaderConf = defaultJsonReaderConf): T =
  T(stream: stream,
    flags: flags,
    conf: conf,
    line: 1,
    lineStartPos: 0,
    tokenStart: -1,
    err: errNone,
  )

# ------------------------------------------------------------------------------
# Public functions
# ------------------------------------------------------------------------------
func isErr*(lex: JsonLexer): bool =
  lex.err != errNone

proc col*(lex: JsonLexer): int =
  lex.stream.pos - lex.lineStartPos

proc tokenStartCol*(lex: JsonLexer): int =
  1 + lex.tokenStart - lex.lineStartPos

proc nonws*(lex: var JsonLexer): char {.gcsafe, raises: [IOError].} =
  lex.skipWhitespace()
  lex.tokenStart = lex.stream.pos
  if lex.readable:
    return lex.peek()

proc scanBool*(lex: var JsonLexer): bool {.gcsafe, raises: [IOError].} =
  case lex.peek
  of 't':
    lex.advance
    # Is this "true"?
    if lex.next != 'r' or
       lex.next != 'u' or
       lex.next != 'e':
       error errInvalidBool
    result = true

  of 'f':
    lex.advance
    # Is this "false"?
    if lex.next != 'a' or
       lex.next != 'l' or
       lex.next != 's' or
       lex.next != 'e':
       error errInvalidBool
    result = false

  else:
    error errInvalidBool

proc scanNull*(lex: var JsonLexer) {.gcsafe, raises: [IOError].} =
  if lex.peek == 'n':
    lex.advance
    # Is this "null"?
    if lex.next != 'u' or
       lex.next != 'l' or
       lex.next != 'l':
       error errInvalidNull
  else:
    error errInvalidNull

proc scanNumber*[T](lex: var JsonLexer, val: var T)
                    {.gcsafe, raises: [IOError].} =

  when T isnot (string or JsonVoid or JsonNumber):
    {.fatal: "`scanNumber` only accepts `string` or `JsonVoid` or `JsonNumber`".}

  when T is JsonNumber:
    lex.scanSign(val.sign, true)
  else:
    lex.scanSign(val, true)

  if not lex.ok: return
  requireMoreNumberChars()

  var
    c = lex.peek()
    fractionDigits = 0
    hasFraction = false

  if c == '.':
    hasFraction = true
    if leadingFraction notin lex.flags:
      error errLeadingFraction
    when T is string:
      val.add '.'
    lex.advance
    requireMoreNumberChars()
    c = lex.peek()
  elif c.isDigit:
    when T is string or T is JsonVoid:
      discard lex.scanInt(val, lex.conf.integerDigitsLimit)
    elif T is JsonNumber:
      discard lex.scanInt(val.integer, lex.conf.integerDigitsLimit)

    if not lex.ok: return
    if not lex.readable: return
    c = lex.peek()
    if c == '.':
      hasFraction = true
      when T is string:
        val.add '.'
      c = eatDigitAndPeek:
        error errEmptyFraction
  else:
    error errNumberExpected

  if c.isDigit:
    when T is string or T is JsonVoid:
      fractionDigits = lex.scanInt(val, lex.conf.fractionDigitsLimit,
        false, errFracDigitLimit)
    elif T is JsonNumber:
      fractionDigits = lex.scanInt(val.fraction, lex.conf.fractionDigitsLimit,
        false, errFracDigitLimit)
    if not lex.ok: return

  if hasFraction and fractionDigits == 0:
    error errEmptyFraction

  if not lex.readable: return
  c = lex.peek()
  if c in {'E', 'e'}:
    when T is string:
      val.add c
    lex.advance
    requireMoreNumberChars()
    when T is JsonNumber:
      lex.scanSign(val.expSign)
    else:
      lex.scanSign(val)
    if not lex.ok: return
    requireMoreNumberChars()
    if not isDigit lex.peek():
      error errNumberExpected

    when T is string or T is JsonVoid:
      discard lex.scanInt(val, lex.conf.exponentDigitsLimit,
        false, errExpDigitLimit)
    elif T is JsonNumber:
      discard lex.scanInt(val.exponent, lex.conf.exponentDigitsLimit,
        false, errExpDigitLimit)

proc scanString*[T](lex: var JsonLexer, val: var T, limit: int)
                    {.gcsafe, raises: [IOError].} =
  ## scanInt only accepts `string` or `JsonVoid`
  ## If all goes ok, parsed-value is returned.
  ## If exceeds string length limit, lex.err = errStringLengthLimit.

  var strLen = 0
  template appendVal(c: untyped) =
    when T is string:
      if limit > 0 and strLen + 1 > limit:
        error errStringLengthLimit
      val.add c
      inc strLen
    elif T is JsonVoid:
      if limit > 0 and strLen + 1 > limit:
        error errStringLengthLimit
      inc strLen
      discard c
    else:
      {.fatal: "`scanString` only accepts `string` or `JsonVoid`".}

  template appendRune(c: untyped) =
    when T is string:
      if limit > 0 and strLen + c.len > limit:
        error errStringLengthLimit
      val.add c
      inc(strLen, c.len)
    else:
      if limit > 0 and strLen + c.len > limit:
        error errStringLengthLimit
      inc(strLen, c.len)

  lex.advance

  while true:
    var c = lex.requireNextChar()
    case c
    of '"':
      break
    of '\\':
      c = lex.requireNextChar()
      case c
      of '\\', '"', '\'', '/':
        appendVal c
      of 'b':
        appendVal '\b'
      of 'f':
        appendVal '\f'
      of 'n':
        appendVal '\n'
      of 'r':
        appendVal '\r'
      of 't':
        appendVal '\t'
      of 'v':
        appendVal '\x0B'
      of '0':
        appendVal '\x00'
      of 'x':
        if escapeHex notin lex.flags:
          error errEscapeHex
        let hex = lex.scanHex
        if not lex.ok: return
        appendVal hex.char
      of 'u':
        var rune = lex.scanHexRune()
        if not lex.ok: return
        # Deal with surrogates
        if (rune and 0xfc00) == 0xd800:
          if lex.requireNextChar() != '\\': error errOrphanSurrogate
          if lex.requireNextChar() != 'u': error errOrphanSurrogate
          let nextRune = lex.scanHexRune()
          if not lex.ok: return
          if (nextRune and 0xfc00) == 0xdc00:
            rune = 0x10000 + (((rune - 0xd800) shl 10) or (nextRune - 0xdc00))

        appendRune toUTF8(Rune(rune))
      else:
        if relaxedEscape notin lex.flags:
          error errRelaxedEscape
        else:
          appendVal c
    of '\x00'..'\x09', '\x0B', '\x0C', '\x0E'..'\x1F':
      error errEscapeControlChar
    of '\r', '\n':
      error errQuoteExpected
    else:
      appendVal c

proc scanValue*[T](lex: var JsonLexer, val: var T)
                   {.gcsafe, raises: [IOError].}

proc tokKind*(lex: var JsonLexer): JsonValueKind
               {.gcsafe, raises: [IOError].}

template parseObjectImpl*(lex: JsonLexer,
                         skipNullFields: static[bool],
                         actionInitial: untyped,
                         actionClosing: untyped,
                         actionComma: untyped,
                         actionKey: untyped,
                         actionValue: untyped,
                         actionError: untyped) =

  lex.enterNestedStructure(actionError)
  actionInitial
  lex.advance

  var
    numElem = 0
    prevComma = false

  while true:
    var next = lex.nonws()
    if not lex.ok: actionError
    if not lex.readable:
      error(lex, errCurlyRiExpected, actionError)
    case next
    of '}':
      lex.advance
      actionClosing
      break
    of ',':
      if prevComma:
        error(lex, errValueExpected, actionError)

      if numElem == 0:
        error(lex, errMissingFirstElement, actionError)

      prevComma = true
      lex.advance
      next = lex.nonws()
      if not lex.ok: actionError
      if next == '}':
        if trailingComma in lex.flags:
          lex.advance
          actionClosing
          break
        else:
          error(lex, errTrailingComma, actionError)
      else:
        actionComma
    of '"':
      if numElem >= 1 and not prevComma:
        error(lex, errCommaExpected, actionError)

      prevComma = false
      inc numElem
      if lex.conf.objectMembersLimit > 0 and
           numElem > lex.conf.objectMembersLimit:
        error(lex, errObjectMembersLimit, actionError)

      actionKey
      if not lex.ok: actionError

      next = lex.nonws()
      if not lex.ok: actionError
      if next != ':':
        error(lex, errColonExpected, actionError)

      lex.advance
      when skipNullFields:
        if lex.tokKind() == JsonValueKind.Null:
          lex.scanNull()
        else:
          actionValue
      else:
        actionValue
      if not lex.ok: actionError
    else:
      error(lex, errStringExpected, actionError)

  lex.exitNestedStructure()

proc scanObject*[T](lex: var JsonLexer, val: var T)
                    {.gcsafe, raises: [IOError].} =
  when T isnot (string or JsonVoid or JsonObjectType):
    {.fatal: "`scanObject` only accepts `string` or `JsonVoid` or `JsonObjectType`".}

  parseObjectImpl(lex, false):
    # initial action
    when T is string:
      val.add '{'
  do:
    # closing action
    when T is string:
      val.add '}'
  do:
    # comma action
    when T is string:
      val.add ','
  do:
    # key action
    when T is JsonVoid:
      lex.scanString(val, lex.conf.stringLengthLimit)
    elif T is string:
      val.add '"'
      lex.scanString(val, lex.conf.stringLengthLimit)
      if lex.ok: val.add '"'
    else:
      var key: string
      lex.scanString(key, lex.conf.stringLengthLimit)
  do:
    # value action
    when T is string:
      val.add ':'
      lex.scanValue(val)
    elif T is JsonVoid:
      lex.scanValue(val)
    else:
      var newVal: valueType(T)
      lex.scanValue(newVal)
      if newVal.isNil.not:
        val[key] = newVal
  do:
    # error action
    return

template parseArrayImpl*(lex: JsonLexer,
                        numElem: untyped,
                        actionInitial: untyped,
                        actionClosing: untyped,
                        actionComma: untyped,
                        actionValue: untyped,
                        actionError: untyped) =

  lex.enterNestedStructure(actionError)
  actionInitial
  lex.advance

  var
    numElem {.inject.} = 0
    prevComma = false

  while true:
    var next = lex.nonws()
    if not lex.ok: actionError
    if not lex.readable:
      error(lex, errBracketRiExpected, actionError)
    case next
    of ']':
      lex.advance
      actionClosing
      break
    of ',':
      if prevComma:
        error(lex, errValueExpected, actionError)

      if numElem == 0:
        # This happens with "[, 1, 2]", for instance
        error(lex, errMissingFirstElement, actionError)

      prevComma = true
      lex.advance
      next = lex.nonws()
      if not lex.ok: actionError

      # Check that this is not a terminating comma (like in
      #  "[b,]")
      if next == ']':
        if trailingComma notin lex.flags:
          error(lex, errTrailingComma, actionError)
        lex.advance
        actionClosing
        break
      else:
        actionComma
    else:
      if numElem >= 1 and not prevComma:
        error(lex, errCommaExpected, actionError)

      if lex.conf.arrayElementsLimit > 0 and
          numElem + 1 > lex.conf.arrayElementsLimit:
        error(lex, errArrayElementsLimit, actionError)

      prevComma = false
      actionValue

      if not lex.ok: actionError
      inc numElem

  lex.exitNestedStructure()

proc scanArray*[T](lex: var JsonLexer, val: var T)
                    {.gcsafe, raises: [IOError].} =
  when T isnot (string or JsonVoid or seq[JsonValueRef]):
    {.fatal: "`scanArray` only accepts `string` or `JsonVoid` or `seq[JsonValueRef]`".}

  parseArrayImpl(lex, numElem) do:
    # initial action
    when T is string:
      val.add '['
  do:
    # closing action
    when T is string:
      val.add ']'
  do:
    # comma action
    when T is string:
      val.add ','
  do:
    # value action
    when T is (string or JsonVoid):
      lex.scanValue(val)
    else:
      val.setLen(numElem + 1)
      lex.scanValue(val[numElem])
  do:
    # error action
    return

proc scanValue*[T](lex: var JsonLexer, val: var T)
                    {.gcsafe, raises: [IOError].} =
  when T isnot (string or JsonVoid or JsonValueRef):
    {.fatal: "`scanValue` only accepts `string` or `JsonVoid` or `JsonValueRef`".}

  var c = lex.nonws()
  if not lex.ok: return

  case c
  of '"':
    when T is JsonValueRef:
      val = T(kind: JsonValueKind.String)
      lex.scanString(val.strVal, lex.conf.stringLengthLimit)
    elif T is string:
      val.add '"'
      lex.scanString(val, lex.conf.stringLengthLimit)
      val.add '"'
    else:
      lex.scanString(val, lex.conf.stringLengthLimit)
    if not lex.ok: return
  of '+', '-', '.', '0'..'9':
    when T is JsonValueRef:
      val = T(kind: JsonValueKind.Number)
      lex.scanNumber(val.numVal)
    else:
      lex.scanNumber(val)
    if not lex.ok: return
  of '{':
    when T is JsonValueRef:
      val = T(kind: JsonValueKind.Object)
      lex.scanObject(val.objVal)
    else:
      lex.scanObject(val)
    if not lex.ok: return
  of '[':
    when T is JsonValueRef:
      val = T(kind: JsonValueKind.Array)
      lex.scanArray(val.arrayVal)
    else:
      lex.scanArray(val)
    if not lex.ok: return
  of 't', 'f':
    when T is JsonVoid:
      discard lex.scanBool()
    else:
      let boolVal = lex.scanBool()

    if not lex.ok: return

    when T is JsonValueRef:
      val = T(kind: JsonValueKind.Bool, boolVal: boolVal)
    elif T is string:
      if boolVal: val.add "true"
      else: val.add "false"
  of 'n':
    lex.scanNull()
    if not lex.ok: return
    when T is JsonValueRef:
      val = T(kind: JsonValueKind.Null)
    elif T is string:
      val.add "null"
  else:
    error errUnknownChar

proc tokKind*(lex: var JsonLexer): JsonValueKind
               {.gcsafe, raises: [IOError].} =
  var c = lex.nonws()
  if not lex.ok: return

  case c
  of '"':
    return JsonValueKind.String
  of '+', '-', '.', '0'..'9':
    return JsonValueKind.Number
  of '{':
    return JsonValueKind.Object
  of '[':
    return JsonValueKind.Array
  of 't', 'f':
    return JsonValueKind.Bool
  of 'n':
    return JsonValueKind.Null
  else:
    error errUnknownChar
