import
  std/[unicode, json],
  faststreams/inputs,
  types

export
  inputs, types

type
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
    tkComma

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

  JsonLexer* = object
    stream*: InputStream
    mode*: JsonMode

    line*: int
    lineStartPos: int
    tokenStart: int

    tok*: TokKind
    err*: JsonErrorKind

    absIntVal*: uint64 # BEWARE: negative integers will have tok == tkNegativeInt
    floatVal*: float
    strVal*: string

const
  powersOfTen = [1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
                 1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
                 1e20, 1e21, 1e22] # TODO: this table should be much larger
                                   # The largest JSON number value is 1E308

proc renderTok*(lexer: JsonLexer, output: var string) =
  case lexer.tok
  of tkError, tkEof:
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

proc hexCharValue(c: char): int {.inline.} =
  case c
  of '0'..'9': ord(c) - ord('0')
  of 'a'..'f': ord(c) - ord('a') + 10
  of 'A'..'F': ord(c) - ord('A') + 10
  else: -1

proc isDigit(c: char): bool {.inline.} =
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
    tok: tkError,
    err: errNone,
    absIntVal: uint64 0,
    floatVal: 0'f,
    strVal: "")

template error(error: JsonErrorKind) {.dirty.} =
  lexer.err = error
  lexer.tok = tkError
  return

template checkForUnexpectedEof {.dirty.} =
  if not lexer.stream.readable:
    error errUnexpectedEof

template requireNextChar(): char =
  checkForUnexpectedEof()
  lexer.stream.read()

template checkForNonPortableInt(val: uint64) =
  if lexer.mode == Portable and val > uint64(maxPortableInt):
    error errNonPortableInt

proc scanHexRune(lexer: var JsonLexer): int =
  for i in 0..3:
    let hexValue = hexCharValue requireNextChar()
    if hexValue == -1: error errHexCharExpected
    result = (result shl 4) or hexValue

proc scanString(lexer: var JsonLexer) =
  lexer.tok = tkString
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
        if lexer.tok == tkError: return
        # Deal with surrogates
        if (rune and 0xfc00) == 0xd800:
          if requireNextChar() != '\\': error errOrphanSurrogate
          if requireNextChar() != 'u': error errOrphanSurrogate
          let nextRune = lexer.scanHexRune()
          if lexer.tok == tkError: return
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

proc handleLF(lexer: var JsonLexer) {.inline.} =
  advance lexer.stream
  lexer.line += 1
  lexer.lineStartPos = lexer.stream.pos

proc skipWhitespace(lexer: var JsonLexer) =
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

proc scanSign(lexer: var JsonLexer): int =
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

proc scanInt(lexer: var JsonLexer): uint64 =
  var c = lexer.stream.peek()
  result = uint64(ord(c) - ord('0'))

  c = eatDigitAndPeek()
  while c.isDigit:
    result = result * 10 + uint64(ord(c) - ord('0'))
    c = eatDigitAndPeek()

proc scanNumber(lexer: var JsonLexer) =
  var sign = lexer.scanSign()
  if sign == 0: return
  var c = lexer.stream.peek()

  if c == '.':
    advance lexer.stream
    requireMoreNumberChars: discard
    lexer.tok = tkFloat
    c = lexer.stream.peek()
  elif c.isDigit:
    lexer.tok = if sign > 0: tkInt
                else: tkNegativeInt
    let scannedValue = lexer.scanInt()
    checkForNonPortableInt scannedValue
    lexer.absIntVal = scannedValue
    if not lexer.stream.readable: return
    c = lexer.stream.peek()
    if c == '.':
      lexer.tok = tkFloat
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

    let exponent = lexer.scanInt()
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
      lexer.tok = tkError
      return
  lexer.tok = expectedTok

proc next*(lexer: var JsonLexer) =
  lexer.skipWhitespace()

  if not lexer.stream.readable:
    lexer.tok = tkEof
    return

  let c = lexer.stream.peek()
  case c
  of '+', '-', '.', '0'..'9':
    lexer.scanNumber()
  of '"':
    lexer.scanString()
  of '[':
    advance lexer.stream
    lexer.tok = tkBracketLe
  of '{':
    advance lexer.stream
    lexer.tok = tkCurlyLe
  of ']':
    advance lexer.stream
    lexer.tok = tkBracketRi
  of '}':
    advance lexer.stream
    lexer.tok = tkCurlyRi
  of ',':
    advance lexer.stream
    lexer.tok = tkComma
  of ':':
    advance lexer.stream
    lexer.tok = tkColon
  of '\0':
    lexer.tok = tkEof
  of 'n': lexer.scanIdentifier("null", tkNull)
  of 't': lexer.scanIdentifier("true", tkTrue)
  of 'f': lexer.scanIdentifier("false", tkFalse)
  else:
    advance lexer.stream
    lexer.tok = tkError

