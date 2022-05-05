import
  std/[unicode, json],
  faststreams/inputs,
  types

export
  inputs, types

{.push raises: [Defect].}

type
  CustomIntHandler* = ##\
    ## Custom decimal integer parser, result values need to be captured
    proc(dgt: int) {.gcsafe, raises: [Defect].}

  CustomByteAction* = enum
    Continue ##\
      ## Default initialisation when provided to a `CustomBlobHandler` parser\
      ## function type via call-by-reference

    StopBeforeByte ##\
      ## Stop feeding and do not consume the current `byte` argument

    StopSwallowByte ##\
      ## Stop and discard current `byte` argument (e.g. the last double quote\
      ## '"' for a genuine string parser.)

  CustomBlobHandler* = ##\
    ## Custom text or binary parser, result values need to be captured. The\
    ## second argument `what` controlls the next action.
    proc(b: byte; what: var CustomByteAction) {.gcsafe, raises: [Defect].}

  TokKind* = enum
    tkError,
    tkEof,
    tkString,
    tkInt,
    tkNegativeInt,
    tkFloat,
    tkTrue,
    tkFalse,
    tkNull,
    tkCurlyLe,
    tkCurlyRi,
    tkBracketLe,
    tkBracketRi,
    tkColon,
    tkComma,

    tkQuoted, ##\
      ## unfinished/lazy type, eventally becomes `tkString`
    tkExBlob, ##\
      ## externally held string value after successful custom parsing

    tkNumeric, ##\
      ## unfinished/lazy type, any of `tkInt`, `tkNegativeInt`, `tkFloat`
    tkExInt, ##\
      ## externally held non-negative integer value after successful custom\
      ## parsing
    tkExNegInt
      ## externally held negative integer value after successful custom parsing

  JsonErrorKind* = enum
    errNone                 = "no error",
    errHexCharExpected      = "hex char expected (part of escape sequence)",
    errStringExpected       = "string expected",
    errColonExpected        = "':' expected",
    errCommaExpected        = "',' expected",
    errBracketRiExpected    = "']' expected",
    errCurlyRiExpected      = "'}' expected",
    errQuoteExpected        = "'\"' or \"'\" expected",
    errNumberExpected       = "number expected",
    errExponentTooLarge     = "exponent too large",
    errUnexpectedEof        = "unexpected end of file",
    errCommentExpected      = "comment expected"
    errOrphanSurrogate      = "unicode surrogates must be followed by another unicode character"
    errNonPortableInt       = "number is outside the range of portable values"
    errCustomIntExpexted    = "not a customised integer"
    errCustomBlobExpexted   = "not a customised quoted blob"

  JsonLexer* = object
    stream*: InputStream
    mode*: JsonMode

    line*: int
    lineStartPos: int
    tokenStart: int

    tokKind: TokKind   # formerly `tok`, now accessible by getter
    err*: JsonErrorKind

    absIntVal*: uint64 # BEWARE: negative integers will have tok == tkNegativeInt
    floatVal*: float
    strVal*: string

const
  powersOfTen = [1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
                 1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
                 1e20, 1e21, 1e22] # TODO: this table should be much larger
                                   # The largest JSON number value is 1E308

# needed in renderTok()
proc scanNumber(lexer: var JsonLexer) {.gcsafe, raises: [Defect,IOError].}
proc scanString(lexer: var JsonLexer) {.gcsafe, raises: [Defect,IOError].}

proc renderTok*(lexer: var JsonLexer, output: var string)
    {.gcsafe, raises: [Defect,IOError].} =
  # The lazy part
  case lexer.tokKind
  of tkNumeric:
    lexer.scanNumber
  of tkQuoted:
    lexer.scanString
  else:
    discard
  # The real stuff
  case lexer.tokKind
  of tkError, tkEof, tkNumeric, tkExInt, tkExNegInt, tkQuoted, tkExBlob:
    discard
  of tkString:
    output.add '"'
    lexer.strVal.escapeJsonUnquoted output
    output.add '"'
  of tkInt:
    output.add $lexer.absIntVal
  of tkNegativeInt:
    output.add '-'
    output.add $lexer.absIntVal
  of tkFloat:
    output.add $lexer.floatVal
  of tkTrue:
    output.add "true"
  of tkFalse:
    output.add "false"
  of tkNull:
    output.add "null"
  of tkCurlyLe:
    output.add '{'
  of tkCurlyRi:
    output.add '}'
  of tkBracketLe:
    output.add '['
  of tkBracketRi:
    output.add ']'
  of tkColon:
    output.add ':'
  of tkComma:
    output.add ','

template peek(s: InputStream): char =
  char inputs.peek(s)

template read(s: InputStream): char =
  char inputs.read(s)

proc hexCharValue(c: char): int =
  case c
  of '0'..'9': ord(c) - ord('0')
  of 'a'..'f': ord(c) - ord('a') + 10
  of 'A'..'F': ord(c) - ord('A') + 10
  else: -1

proc isDigit(c: char): bool =
  return (c >= '0' and c <= '9')

proc col*(lexer: JsonLexer): int =
  lexer.stream.pos - lexer.lineStartPos

proc tokenStartCol*(lexer: JsonLexer): int =
  1 + lexer.tokenStart - lexer.lineStartPos

proc init*(T: type JsonLexer, stream: InputStream, mode = defaultJsonMode): T =
  T(stream: stream,
    mode: mode,
    line: 1,
    lineStartPos: 0,
    tokenStart: -1,
    tokKind: tkError,
    err: errNone,
    absIntVal: uint64 0,
    floatVal: 0'f,
    strVal: "")

template error(error: JsonErrorKind) {.dirty.} =
  lexer.err = error
  lexer.tokKind = tkError
  return

template checkForUnexpectedEof {.dirty.} =
  if not lexer.stream.readable:
    error errUnexpectedEof

template requireNextChar(): char =
  checkForUnexpectedEof()
  lexer.stream.read()

template checkForNonPortableInt(val: uint64; overflow: bool) =
  if overflow or (lexer.mode == Portable and val > uint64(maxPortableInt)):
    error errNonPortableInt

proc scanHexRune(lexer: var JsonLexer): int
    {.gcsafe, raises: [Defect,IOError].} =
  for i in 0..3:
    let hexValue = hexCharValue requireNextChar()
    if hexValue == -1: error errHexCharExpected
    result = (result shl 4) or hexValue

proc scanString(lexer: var JsonLexer) =
  lexer.tokKind = tkString
  lexer.strVal.setLen 0
  lexer.tokenStart = lexer.stream.pos

  advance lexer.stream

  while true:
    var c = requireNextChar()
    case c
    of '"':
      break
    of '\\':
      c = requireNextChar()
      case c
      of '\\', '"', '\'', '/':
        lexer.strVal.add c
      of 'b':
        lexer.strVal.add '\b'
      of 'f':
        lexer.strVal.add '\f'
      of 'n':
        lexer.strVal.add '\n'
      of 'r':
        lexer.strVal.add '\r'
      of 't':
        lexer.strVal.add '\t'
      of 'v':
        lexer.strVal.add '\x0B'
      of '0':
        lexer.strVal.add '\x00'
      of 'u':
        var rune = lexer.scanHexRune()
        if lexer.tokKind == tkError: return
        # Deal with surrogates
        if (rune and 0xfc00) == 0xd800:
          if requireNextChar() != '\\': error errOrphanSurrogate
          if requireNextChar() != 'u': error errOrphanSurrogate
          let nextRune = lexer.scanHexRune()
          if lexer.tokKind == tkError: return
          if (nextRune and 0xfc00) == 0xdc00:
            rune = 0x10000 + (((rune - 0xd800) shl 10) or (nextRune - 0xdc00))
        lexer.strVal.add toUTF8(Rune(rune))
      else:
        # don't bother with the error
        lexer.strVal.add c
    of '\r', '\n':
      error errQuoteExpected
    else:
      lexer.strVal.add c

proc handleLF(lexer: var JsonLexer) =
  advance lexer.stream
  lexer.line += 1
  lexer.lineStartPos = lexer.stream.pos

proc skipWhitespace(lexer: var JsonLexer)
    {.gcsafe, raises: [Defect,IOError].} =
  template handleCR =
    # Beware: this is a template, because the return
    # statement has to exit `skipWhitespace`.
    advance lexer.stream
    if not lexer.stream.readable: return
    if lexer.stream.peek() == '\n': advance lexer.stream
    lexer.line += 1
    lexer.lineStartPos = lexer.stream.pos

  while lexer.stream.readable:
    case lexer.stream.peek()
    of '/':
      advance lexer.stream
      checkForUnexpectedEof()
      case lexer.stream.peek()
      of '/':
        advance lexer.stream
        while true:
          if not lexer.stream.readable: return
          case lexer.stream.peek()
          of '\r':
            handleCR()
            break
          of '\n':
            lexer.handleLF()
            break
          else:
            advance lexer.stream
      of '*':
        advance lexer.stream
        while true:
          if not lexer.stream.readable: return
          case lexer.stream.peek()
          of '\r':
            handleCR()
          of '\n':
            lexer.handleLF()
          of '*':
            advance lexer.stream
            checkForUnexpectedEof()
            if lexer.stream.peek() == '/':
              advance lexer.stream
              break
          else:
            advance lexer.stream
      else:
        error errCommentExpected
    of ' ', '\t':
      advance lexer.stream
    of '\r':
      handleCR()
    of '\n':
      lexer.handleLF()
    else:
      break

template requireMoreNumberChars(elseClause) =
  if not lexer.stream.readable:
    elseClause
    error errNumberExpected

template eatDigitAndPeek: char =
  advance lexer.stream
  if not lexer.stream.readable: return
  lexer.stream.peek()

proc scanSign(lexer: var JsonLexer): int
    {.gcsafe, raises: [Defect,IOError].} =
  # Returns +1 or -1
  # If a sign character is present, it must be followed
  # by more characters representing the number. If this
  # is not the case, the return value will be 0.
  let c = lexer.stream.peek()
  if c == '-':
    requireMoreNumberChars: result = 0
    advance lexer.stream
    return -1
  elif c == '+':
    requireMoreNumberChars: result = 0
    advance lexer.stream
  return 1

proc scanInt(lexer: var JsonLexer): (uint64,bool)
    {.gcsafe, raises: [Defect,IOError].} =
  ## Scan unsigned integer into uint64 if possible.
  ## If all goes ok, the tuple `(parsed-value,false)` is returned.
  ## On overflow, the tuple `(uint64.high,true)` is returned.
  var c = lexer.stream.peek()

  # Always possible to append `9` is result[0] is not larger
  const canAppendDigit9 = (uint64.high - 9) div 10

  result[0] = uint64(ord(c) - ord('0'))

  c = eatDigitAndPeek() # implicit auto-return
  while c.isDigit:
    # Process next digit unless overflow
    if not result[1]:
      let lsDgt = uint64(ord(c) - ord('0'))
      if canAppendDigit9 < result[0] and
          (uint64.high - lsDgt) div 10 < result[0]:
        result[1] = true
        result[0] = uint64.high
      else:
        result[0] = result[0] * 10 + lsDgt
    # Fetch next digit
    c = eatDigitAndPeek() # implicit auto-return


proc scanNumber(lexer: var JsonLexer)
    {.gcsafe, raises: [Defect,IOError].} =
  var sign = lexer.scanSign()
  if sign == 0: return
  var c = lexer.stream.peek()

  if c == '.':
    advance lexer.stream
    requireMoreNumberChars: discard
    lexer.tokKind = tkFloat
    c = lexer.stream.peek()
  elif c.isDigit:
    lexer.tokKind = if sign > 0: tkInt
                    else: tkNegativeInt
    let (scannedValue,overflow) = lexer.scanInt()
    checkForNonPortableInt scannedValue, overflow
    lexer.absIntVal = scannedValue
    if not lexer.stream.readable: return
    c = lexer.stream.peek()
    if c == '.':
      lexer.tokKind = tkFloat
      lexer.floatVal = float(lexer.absIntVal) * float(sign)
      c = eatDigitAndPeek()
  else:
    error errNumberExpected

  var fraction = 0.1'f
  while c.isDigit:
    lexer.floatVal += fraction * float(ord(c) - ord('0'))
    fraction *= 0.1'f
    c = eatDigitAndPeek()

  if c in {'E', 'e'}:
    advance lexer.stream
    requireMoreNumberChars: discard
    let sign = lexer.scanSign()
    if sign == 0: return
    if not isDigit lexer.stream.peek():
      error errNumberExpected

    let (exponent,_) = lexer.scanInt()
    if exponent >= uint64(len(powersOfTen)):
      error errExponentTooLarge

    if sign > 0:
      lexer.floatVal = lexer.floatVal * powersOfTen[exponent]
    else:
      lexer.floatVal = lexer.floatVal / powersOfTen[exponent]

proc scanIdentifier(lexer: var JsonLexer,
                    expectedIdent: string, expectedTok: TokKind) =
  for c in expectedIdent:
    if c != lexer.stream.read():
      lexer.tokKind = tkError
      return
  lexer.tokKind = expectedTok

proc accept*(lexer: var JsonLexer)
    {.gcsafe, raises: [Defect,IOError].} =
  ## Finalise token by parsing the value. Note that this might change
  ## the token type
  case lexer.tokKind
  of tkNumeric:
    lexer.scanNumber
  of tkQuoted:
    lexer.scanString
  else:
    discard

proc next*(lexer: var JsonLexer)
    {.gcsafe, raises: [Defect,IOError].} =
  lexer.skipWhitespace()

  if not lexer.stream.readable:
    lexer.tokKind = tkEof
    return

  # in case the value parsing was missing
  lexer.accept()
  lexer.strVal.setLen 0 # release memory (if any)

  let c = lexer.stream.peek()
  case c
  of '+', '-', '.', '0'..'9':
    lexer.tokKind = tkNumeric
  of '"':
    lexer.tokKind = tkQuoted
  of '[':
    advance lexer.stream
    lexer.tokKind = tkBracketLe
  of '{':
    advance lexer.stream
    lexer.tokKind = tkCurlyLe
  of ']':
    advance lexer.stream
    lexer.tokKind = tkBracketRi
  of '}':
    advance lexer.stream
    lexer.tokKind = tkCurlyRi
  of ',':
    advance lexer.stream
    lexer.tokKind = tkComma
  of ':':
    advance lexer.stream
    lexer.tokKind = tkColon
  of '\0':
    lexer.tokKind = tkEof
  of 'n': lexer.scanIdentifier("null", tkNull)
  of 't': lexer.scanIdentifier("true", tkTrue)
  of 'f': lexer.scanIdentifier("false", tkFalse)
  else:
    advance lexer.stream
    lexer.tokKind = tkError

proc tok*(lexer: var JsonLexer): TokKind
    {.gcsafe, raises: [Defect,IOError].} =
  ## Getter, implies full token parsing
  lexer.accept
  lexer.tokKind

proc lazyTok*(lexer: JsonLexer): TokKind =
  ## Preliminary token state unless accepted, already
  lexer.tokKind


proc customIntHandler*(lexer: var JsonLexer; handler: CustomIntHandler)
    {.gcsafe, raises: [Defect,IOError].} =
  ## Apply the `handler` argument function for parsing a `tkNumeric` type
  ## value. This function sets the token state to `tkExInt`, `tkExNegInt`,
  ## or `tkError`.
  proc customScan(lexer: var JsonLexer)
    {.gcsafe, raises: [Defect,IOError].} =
    var c = lexer.stream.peek()
    handler(ord(c) - ord('0'))
    c = eatDigitAndPeek()   # implicit auto-return
    while c.isDigit:
      handler(ord(c) - ord('0'))
      c = eatDigitAndPeek() # implicit auto-return

  if lexer.tokKind == tkNumeric:
    var sign = lexer.scanSign()
    if sign != 0:
      if lexer.stream.peek.isDigit:
        lexer.tokKind = if 0 < sign: tkExInt else: tkExNegInt
        lexer.customScan
        if not lexer.stream.readable or lexer.stream.peek != '.':
          return

  error errCustomIntExpexted

proc customBlobHandler*(lexer: var JsonLexer; handler: CustomBlobHandler)
    {.gcsafe, raises: [Defect,IOError].} =
  ## Apply the `handler` argument function for parsing a `tkQuoted` type
  ## value. This function sets the token state to `tkExBlob`, or `tkError`.
  proc customScan(lexer: var JsonLexer)
      {.gcsafe, raises: [Defect,IOError].} =
    var what = Continue
    while lexer.stream.readable:
      var c = lexer.stream.peek
      handler(c.byte, what)
      case what
      of StopBeforeByte:
        break
      of StopSwallowByte:
        advance lexer.stream
        break
      of Continue:
        advance lexer.stream

  if lexer.tokKind == tkQuoted:
    advance lexer.stream
    lexer.tokKind = tkExBlob
    lexer.customScan
    return

  error errCustomBlobExpexted


template customIntValueIt*(lexer: var JsonLexer; body: untyped): untyped =
  ## Convenience wrapper around `customIntHandler()` for parsing integers.
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## digit processing can be exited with `return`.
  var handler: CustomIntHandler =
    proc(digit: int) =
      let it {.inject.} = digit
      body
  lexer.customIntHandler(handler)

template customBlobValueIt*(lexer: var JsonLexer; body: untyped): untyped =
  ## Convenience wrapper around `customBlobHandler()` for parsing any byte
  ## object. The body function needs to terminate explicitely with the typical
  ## phrase `doNext = StopSwallowByte` or with the more unusual phrase
  ## `doNext = StopBeforeByte`.
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## byte processing can be exited with `return`.
  var handler: CustomBlobHandler =
    proc(c: byte; what: var CustomByteAction) =
      let it {.inject.} = c
      var doNext {.inject.} = what
      body
      what = doNext
  lexer.customBlobHandler(handler)

template customTextValueIt*(lexer: var JsonLexer; body: untyped): untyped =
  ## Convenience wrapper around `customBlobHandler()` for parsing a text
  ## terminating with a double quote character '"' (no inner double quote
  ## allowed.)
  ##
  ## The `body` argument represents a virtual function body. So the current
  ## character processing can be exited with `return`.
  var handler: CustomBlobHandler =
    proc(c: byte; what: var CustomByteAction) =
      let it {.inject.} = c.chr
      if it == '"':
        what = StopSwallowByte
      else:
        body
  lexer.customBlobHandler(handler)
