# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  faststreams,
  unittest2

# we want to test lexer internals
# hence use include instead of import
include
  ../json_serialization/lexer

template testScanInt(input: string, output: untyped, limit: int = 32, error: JsonErrorKind = errNone) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream)
  type T = type output
  var value: T
  discard lex.scanInt(value, limit)
  check:
    value == output
    lex.err == error

template testScanBool(input: string, expectedOutput: untyped, error: JsonErrorKind = errNone) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream)
  check:
    lex.scanBool() == expectedOutput
    lex.err == error

template testScanNull(input: string, error: JsonErrorKind = errNone) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream)
  lex.scanNull()
  check:
    lex.err == error

template testScanString(input: string, output: untyped,
                        limit: int = 64,
                        error: JsonErrorKind = errNone) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream)
  type T = type output
  var value: T
  lex.scanString(value, limit)
  check:
    value == output
    lex.err == error

template testScanString(input: string, output: untyped,
                        limit: int = 64,
                        error: JsonErrorKind = errNone,
                        flags: JsonReaderFlags) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream, flags)
  type T = type output
  var value: T
  lex.scanString(value, limit)
  check:
    value == output
    lex.err == error

template testScanNumber(input: string, output: untyped,
                        error: JsonErrorKind = errNone,
                        conf: JsonReaderConf = defaultJsonReaderConf) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream, defaultJsonReaderFlags, conf)
  type T = type output
  var value: T
  lex.scanNumber(value)
  check:
    value == output
    lex.err == error

template testScanNumber(input: string, output: untyped,
                        error: JsonErrorKind = errNone,
                        conf: JsonReaderConf = defaultJsonReaderConf,
                        flags: JsonReaderFlags) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream, flags, conf)
  type T = type output
  var value: T
  lex.scanNumber(value)
  check:
    value == output
    lex.err == error

template testScanValue(input: string, output: untyped,
                        error: JsonErrorKind = errNone,
                        conf: JsonReaderConf = defaultJsonReaderConf) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream, defaultJsonReaderFlags, conf)
  type T = type output
  var value: T
  lex.scanValue(value)
  check:
    value == output
    lex.err == error

template testScanValue(input: string, output: untyped,
                        error: JsonErrorKind = errNone,
                        conf: JsonReaderConf = defaultJsonReaderConf,
                        flags: JsonReaderFlags) =
  var stream = unsafeMemoryInput(input)
  var lex = init(JsonLexer, stream, flags, conf)
  type T = type output
  var value: T
  lex.scanValue(value)
  check:
    value == output
    lex.err == error

suite "numbers test suite":
  test "scanInt string":
    testScanInt("1234567890", "1234567890")
    testScanInt("01234567890", "0", error = errLeadingZero)
    testScanInt("0", "0")
    testScanInt("0a1234567890", "0")
    testScanInt("00", "0", error = errLeadingZero)

    testScanInt("1234", "123", limit = 3, error = errIntDigitLimit)
    testScanInt("01234", "0", limit = 3, error = errLeadingZero)

  test "scanInt uint64":
    testScanInt("1234567890", 1234567890'u64)
    testScanInt("01234567890", 0'u64, error = errLeadingZero)
    testScanInt("0", 0'u64)
    testScanInt("0a1234567890", 0'u64)
    testScanInt("00", 0'u64, error = errLeadingZero)

    testScanInt("18446744073709551615", 18446744073709551615'u64)
    testScanInt("18446744073709551616", 18446744073709551615'u64, error = errU64Overflow)

    testScanInt("1234", 123'u64, limit = 3, error = errIntDigitLimit)

  test "scanInt JsonVoid":
    testScanInt("1234567890", JsonVoid())
    testScanInt("01234567890", JsonVoid(), error = errLeadingZero)
    testScanInt("0", JsonVoid())
    testScanInt("0a1234567890", JsonVoid())
    testScanInt("00", JsonVoid(), error = errLeadingZero)

    testScanInt("18446744073709551615", JsonVoid())
    testScanInt("18446744073709551616", JsonVoid())

    testScanInt("1234", JsonVoid(), limit = 3, error = errIntDigitLimit)

  test "scanBool":
    testScanBool("true", true)
    testScanBool("false", false)

    testScanBool("trur", false, error = errInvalidBool)
    testScanBool("t", false, error = errInvalidBool)
    testScanBool("tr", false, error = errInvalidBool)
    testScanBool("tru", false, error = errInvalidBool)

    testScanBool("f", false, error = errInvalidBool)
    testScanBool("fa", false, error = errInvalidBool)
    testScanBool("fal", false, error = errInvalidBool)
    testScanBool("fals", false, error = errInvalidBool)

  test "scanNull":
    testScanNull("null")
    testScanNull("n", error = errInvalidNull)
    testScanNull("nu", error = errInvalidNull)
    testScanNull("nul", error = errInvalidNull)

  test "scanString unicode":
    testScanString("\"\\u0\"", "", error = errHexCharExpected)
    testScanString("\"\\u111\"", "", error = errHexCharExpected)
    testScanString("\"\\U0", "", error = errRelaxedEscape)
    testScanString("\"\\x00\"", "", error = errEscapeHex)
    testScanString("\"\\u0011\"", "\x11")

    ## surrogate pair
    testScanString("\"\\uD800\"", "", error = errOrphanSurrogate)
    testScanString("\"\\uDFFF\"", "\uDFFF")
    testScanString("\"\\uD7FF\"", "\uD7FF")
    testScanString("\"\\uE000\"", "\uE000")
    testScanString("\"\\u0000\"", "\x00")

    testScanString("\"\\u111\"", "", error = errHexCharExpected)

    testScanString("\"\\7\"", "7", flags = {JsonReaderFlag.relaxedEscape})
    testScanString("\"\\x12\"", "\x12", flags = {JsonReaderFlag.escapeHex})

    testScanString("\"\\7\\x12ab\"", "7\x12a",
      limit = 3,
      flags = {JsonReaderFlag.relaxedEscape, JsonReaderFlag.escapeHex},
      error = errStringLengthLimit)

  test "scanString basic":
    testScanString("\"\"", "")
    testScanString("\"hello\"", "hello")
    testScanString("\"hel\\nlo\"", "hel\nlo")

    testScanString("\"he\nllo\"", "he", error = errQuoteExpected)
    testScanString("\"hello", "hello", error = errUnexpectedEof)


    testScanString("\"hello\\uD7FF\"", "hello\uD7FF")
    testScanString("\"\\\"\\\\\\b\\f\\n\\r\\t\"", "\"\\\b\f\n\r\t")

    testScanString("\"Обычный текст в кодировке UTF-8\"",
      "Обычный текст в кодировке UTF-8")

  test "scanString unicode JsonVoid":
    testScanString("\"\\u0\"", JsonVoid(), error = errHexCharExpected)
    testScanString("\"\\u111\"", JsonVoid(), error = errHexCharExpected)
    testScanString("\"\\U0", JsonVoid(), error = errRelaxedEscape)
    testScanString("\"\\x00\"", JsonVoid(), error = errEscapeHex)
    testScanString("\"\\u0011\"", JsonVoid())

    # surrogate pair
    testScanString("\"\\uD800\"", JsonVoid(), error = errOrphanSurrogate)
    testScanString("\"\\uDFFF\"", JsonVoid())
    testScanString("\"\\uD7FF\"", JsonVoid())
    testScanString("\"\\uE000\"", JsonVoid())
    testScanString("\"\\u0000\"", JsonVoid())

    testScanString("\"\\u111\"", JsonVoid(), error = errHexCharExpected)

    testScanString("\"\\7\"", JsonVoid(), flags = {JsonReaderFlag.relaxedEscape})
    testScanString("\"\\x12\"", JsonVoid(), flags = {JsonReaderFlag.escapeHex})

    testScanString("\"\\7\\x12ab\"", JsonVoid(),
      limit = 3,
      flags = {JsonReaderFlag.relaxedEscape, JsonReaderFlag.escapeHex},
      error = errStringLengthLimit)

  test "scanString basic JsonVoid":
    testScanString("\"\"", JsonVoid())
    testScanString("\"hello\"", JsonVoid())
    testScanString("\"hel\\nlo\"", JsonVoid())

    testScanString("\"he\nllo\"", JsonVoid(), error = errQuoteExpected)
    testScanString("\"hello", JsonVoid(), error = errUnexpectedEof)


    testScanString("\"hello\\uD7FF\"", JsonVoid())
    testScanString("\"\\\"\\\\\\b\\f\\n\\r\\t\"", JsonVoid())

    testScanString("\"Обычный текст в кодировке UTF-8\"", JsonVoid())

  test "scanNumber integer part string":
    testScanNumber("0", "0")
    testScanNumber("+0", "+0")
    testScanNumber("-0", "-0")

    testScanNumber("+", "+", error = errNumberExpected)
    testScanNumber("-", "-", error = errNumberExpected)

    testScanNumber("+a", "+", error = errNumberExpected)
    testScanNumber("-b", "-", error = errNumberExpected)

    testScanNumber("01", "0", error = errLeadingZero)
    testScanNumber("+01", "+0", error = errLeadingZero)
    testScanNumber("-01", "-0", error = errLeadingZero)

    testScanNumber("1234", "1234")

    var conf = defaultJsonReaderConf
    conf.integerDigitsLimit = 3
    testScanNumber("1234", "123", error = errIntDigitLimit, conf = conf)

  test "scanNumber fractional part string":
    testScanNumber("0.0", "0.0")
    testScanNumber("+0.1", "+0.1")
    testScanNumber("-0.2", "-0.2")

    testScanNumber(".1", "", flags = {}, error = errLeadingFraction)
    testScanNumber(".1", ".1")

    var conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber(".1234", ".123", error = errFracDigitLimit, conf = conf)

    testScanNumber("1234.5555", "1234.5555")

    conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber("1234.1234", "1234.123", error = errFracDigitLimit, conf = conf)

  test "scanNumber exponent part string":
    testScanNumber("0.0E1", "0.0E1")
    testScanNumber("+0.1e2", "+0.1e2")
    testScanNumber("-0.2e9", "-0.2e9")

    testScanNumber("0.0E-1", "0.0E-1")
    testScanNumber("+0.1e-2", "+0.1e-2")
    testScanNumber("-0.2e-9", "-0.2e-9")

    testScanNumber("0.0E+1", "0.0E+1")
    testScanNumber("+0.1e+2", "+0.1e+2")
    testScanNumber("-0.2e+9", "-0.2e+9")

    testScanNumber("0.0E", "0.0E", error = errNumberExpected)
    testScanNumber("+0.1e", "+0.1e", error = errNumberExpected)
    testScanNumber("-0.2e", "-0.2e", error = errNumberExpected)

    testScanNumber("0.0E-", "0.0E-", error = errNumberExpected)
    testScanNumber("+0.1e+", "+0.1e+", error = errNumberExpected)
    testScanNumber("-0.2e+", "-0.2e+", error = errNumberExpected)

    var conf = defaultJsonReaderConf
    conf.exponentDigitsLimit = 3
    testScanNumber("-0.2e+1234", "-0.2e+123", error = errExpDigitLimit, conf = conf)

  test "scanNumber integer part JsonVoid":
    testScanNumber("0", JsonVoid())
    testScanNumber("+0", JsonVoid())
    testScanNumber("-0", JsonVoid())

    testScanNumber("+", JsonVoid(), error = errNumberExpected)
    testScanNumber("-", JsonVoid(), error = errNumberExpected)

    testScanNumber("+a", JsonVoid(), error = errNumberExpected)
    testScanNumber("-b", JsonVoid(), error = errNumberExpected)

    testScanNumber("01", JsonVoid(), error = errLeadingZero)
    testScanNumber("+01", JsonVoid(), error = errLeadingZero)
    testScanNumber("-01", JsonVoid(), error = errLeadingZero)

    testScanNumber("1234", JsonVoid())

    var conf = defaultJsonReaderConf
    conf.integerDigitsLimit = 3
    testScanNumber("1234", JsonVoid(), error = errIntDigitLimit, conf = conf)

  test "scanNumber fractional part JsonVoid":
    testScanNumber("0.0", JsonVoid())
    testScanNumber("+0.1", JsonVoid())
    testScanNumber("-0.2", JsonVoid())

    testScanNumber(".1", JsonVoid(), flags = {}, error = errLeadingFraction)
    testScanNumber(".1", JsonVoid())

    var conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber(".1234", JsonVoid(), error = errFracDigitLimit, conf = conf)

    testScanNumber("1234.5555", JsonVoid())

    conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber("1234.1234", JsonVoid(), error = errFracDigitLimit, conf = conf)

  test "scanNumber exponent part JsonVoid":
    testScanNumber("0.0E1", JsonVoid())
    testScanNumber("+0.1e2", JsonVoid())
    testScanNumber("-0.2e9", JsonVoid())

    testScanNumber("0.0E-1", JsonVoid())
    testScanNumber("+0.1e-2", JsonVoid())
    testScanNumber("-0.2e-9", JsonVoid())

    testScanNumber("0.0E+1", JsonVoid())
    testScanNumber("+0.1e+2", JsonVoid())
    testScanNumber("-0.2e+9", JsonVoid())

    testScanNumber("0.0E", JsonVoid(), error = errNumberExpected)
    testScanNumber("+0.1e", JsonVoid(), error = errNumberExpected)
    testScanNumber("-0.2e", JsonVoid(), error = errNumberExpected)

    testScanNumber("0.0E-", JsonVoid(), error = errNumberExpected)
    testScanNumber("+0.1e+", JsonVoid(), error = errNumberExpected)
    testScanNumber("-0.2e+", JsonVoid(), error = errNumberExpected)

    var conf = defaultJsonReaderConf
    conf.exponentDigitsLimit = 3
    testScanNumber("-0.2e+1234", JsonVoid(), error = errExpDigitLimit, conf = conf)

  test "scanNumber integer part JsonNumber[string]":
    testScanNumber("0", JsonNumber[string](integer: "0"))
    testScanNumber("+0", JsonNumber[string](sign: JsonSign.Pos, integer: "0"))
    testScanNumber("-0", JsonNumber[string](sign: JsonSign.Neg, integer: "0"))

    testScanNumber("+", JsonNumber[string](sign: JsonSign.Pos), error = errNumberExpected)
    testScanNumber("-", JsonNumber[string](sign: JsonSign.Neg), error = errNumberExpected)

    testScanNumber("+a", JsonNumber[string](sign: JsonSign.Pos), error = errNumberExpected)
    testScanNumber("-b", JsonNumber[string](sign: JsonSign.Neg), error = errNumberExpected)

    testScanNumber("01", JsonNumber[string](integer: "0"), error = errLeadingZero)
    testScanNumber("+01", JsonNumber[string](sign: JsonSign.Pos,
      integer: "0"), error = errLeadingZero)
    testScanNumber("-01", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0"), error = errLeadingZero)

    testScanNumber("1234", JsonNumber[string](integer: "1234"))

    var conf = defaultJsonReaderConf
    conf.integerDigitsLimit = 3
    testScanNumber("1234", JsonNumber[string](integer: "123"),
      error = errIntDigitLimit, conf = conf)

  test "scanNumber fractional part JsonNumber[string]":
    testScanNumber("0.0", JsonNumber[string](integer: "0", fraction: "0"))
    testScanNumber("+0.1", JsonNumber[string](sign: JsonSign.Pos, integer: "0", fraction: "1"))
    testScanNumber("-0.2", JsonNumber[string](sign: JsonSign.Neg, integer: "0", fraction: "2"))

    testScanNumber(".1", JsonNumber[string](), flags = {}, error = errLeadingFraction)
    testScanNumber(".1", JsonNumber[string](fraction: "1"))

    var conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber(".1234", JsonNumber[string](fraction: "123"),
      error = errFracDigitLimit, conf = conf)

    testScanNumber("1234.5555", JsonNumber[string](integer: "1234", fraction: "5555"))

    conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber("1234.1234", JsonNumber[string](integer: "1234", fraction: "123"),
      error = errFracDigitLimit, conf = conf)

  test "scanNumber exponent part JsonNumber[string]":
    testScanNumber("0.0E1", JsonNumber[string](integer: "0", fraction: "0", exponent: "1"))
    testScanNumber("+0.1e2", JsonNumber[string](sign: JsonSign.Pos,
      integer: "0", fraction: "1", exponent: "2"))
    testScanNumber("-0.2e9", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0", fraction: "2", exponent: "9"))

    testScanNumber("0.0E-1", JsonNumber[string](integer: "0", fraction: "0",
      expSign: JsonSign.Neg, exponent: "1"))
    testScanNumber("+0.1e-2", JsonNumber[string](sign: JsonSign.Pos,
      integer: "0", fraction: "1", expSign: JsonSign.Neg, exponent: "2"))
    testScanNumber("-0.2e-9", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0", fraction: "2", expSign: JsonSign.Neg, exponent: "9"))

    testScanNumber("0.0E+1", JsonNumber[string](integer: "0",
      fraction: "0", expSign: JsonSign.Pos, exponent: "1"))
    testScanNumber("+0.1e+2", JsonNumber[string](sign: JsonSign.Pos,
      integer: "0", fraction: "1", expSign: JsonSign.Pos, exponent: "2"))
    testScanNumber("-0.2e+9", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0", fraction: "2", expSign: JsonSign.Pos, exponent: "9"))

    testScanNumber("0.0E", JsonNumber[string](integer: "0", fraction: "0"),
      error = errNumberExpected)
    testScanNumber("+0.1e", JsonNumber[string](sign: JsonSign.Pos,
      integer: "0", fraction: "1"), error = errNumberExpected)
    testScanNumber("-0.2e", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0", fraction: "2"), error = errNumberExpected)

    testScanNumber("0.0E-", JsonNumber[string](integer: "0", fraction: "0",
      expSign: JsonSign.Neg), error = errNumberExpected)
    testScanNumber("+0.1e+", JsonNumber[string](sign: JsonSign.Pos,
      integer: "0", fraction: "1", expSign: JsonSign.Pos), error = errNumberExpected)
    testScanNumber("-0.2e+", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0", fraction: "2", expSign: JsonSign.Pos), error = errNumberExpected)

    var conf = defaultJsonReaderConf
    conf.exponentDigitsLimit = 3
    testScanNumber("-0.2e+1234", JsonNumber[string](sign: JsonSign.Neg,
      integer: "0", fraction: "2", expSign: JsonSign.Pos, exponent: "123"),
      error = errExpDigitLimit, conf = conf)

  test "scanNumber integer part JsonNumber[uint64]":
    testScanNumber("0", JsonNumber[uint64](integer: 0))
    testScanNumber("+0", JsonNumber[uint64](sign: JsonSign.Pos, integer: 0))
    testScanNumber("-0", JsonNumber[uint64](sign: JsonSign.Neg, integer: 0))

    testScanNumber("+", JsonNumber[uint64](sign: JsonSign.Pos), error = errNumberExpected)
    testScanNumber("-", JsonNumber[uint64](sign: JsonSign.Neg), error = errNumberExpected)

    testScanNumber("+a", JsonNumber[uint64](sign: JsonSign.Pos), error = errNumberExpected)
    testScanNumber("-b", JsonNumber[uint64](sign: JsonSign.Neg), error = errNumberExpected)

    testScanNumber("01", JsonNumber[uint64](integer: 0), error = errLeadingZero)
    testScanNumber("+01", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 0), error = errLeadingZero)
    testScanNumber("-01", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 0), error = errLeadingZero)

    testScanNumber("1234", JsonNumber[uint64](integer: 1234))

    var conf = defaultJsonReaderConf
    conf.integerDigitsLimit = 3
    testScanNumber("1234", JsonNumber[uint64](integer: 123),
      error = errIntDigitLimit, conf = conf)

  test "scanNumber fractional part JsonNumber[uint64]":
    testScanNumber("3.0", JsonNumber[uint64](integer: 3, fraction: "0"))
    testScanNumber("+3.1", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 3, fraction: "1"))
    testScanNumber("-3.2", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 3, fraction: "2"))

    testScanNumber(".1", JsonNumber[uint64](), flags = {}, error = errLeadingFraction)
    testScanNumber(".1", JsonNumber[uint64](fraction: "1"))

    var conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 4
    testScanNumber(".12345", JsonNumber[uint64](fraction: "1234"),
      error = errFracDigitLimit, conf = conf)

    testScanNumber("1234.5555", JsonNumber[uint64](integer: 1234, fraction: "5555"))

    conf = defaultJsonReaderConf
    conf.fractionDigitsLimit = 3
    testScanNumber("1234.1234", JsonNumber[uint64](integer: 1234, fraction: "123"),
      error = errFracDigitLimit, conf = conf)

  test "scanNumber exponent part JsonNumber[uint64]":
    testScanNumber("4.0E1", JsonNumber[uint64](integer: 4, fraction: "0", exponent: 1))
    testScanNumber("+4.1e2", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 4, fraction: "1", exponent: 2))
    testScanNumber("-4.2e9", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 4, fraction: "2", exponent: 9))

    testScanNumber("0.0E-1", JsonNumber[uint64](integer: 0, fraction: "0",
      expSign: JsonSign.Neg, exponent: 1))
    testScanNumber("+0.1e-2", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 0, fraction: "1", expSign: JsonSign.Neg, exponent: 2))
    testScanNumber("-0.2e-9", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 0, fraction: "2", expSign: JsonSign.Neg, exponent: 9))

    testScanNumber("0.0E+1", JsonNumber[uint64](integer: 0, fraction: "0",
      expSign: JsonSign.Pos, exponent: 1))
    testScanNumber("+0.1e+2", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 0, fraction: "1", expSign: JsonSign.Pos, exponent: 2))
    testScanNumber("-0.2e+9", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 0, fraction: "2", expSign: JsonSign.Pos, exponent: 9))

    testScanNumber("0.0E", JsonNumber[uint64](integer: 0, fraction: "0"),
      error = errNumberExpected)
    testScanNumber("+0.1e", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 0, fraction: "1"), error = errNumberExpected)
    testScanNumber("-0.2e", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 0, fraction: "2"), error = errNumberExpected)

    testScanNumber("0.0E-", JsonNumber[uint64](integer: 0, fraction: "0",
      expSign: JsonSign.Neg), error = errNumberExpected)
    testScanNumber("+0.1e+", JsonNumber[uint64](sign: JsonSign.Pos,
      integer: 0, fraction: "1", expSign: JsonSign.Pos), error = errNumberExpected)
    testScanNumber("-0.2e+", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 0, fraction: "2", expSign: JsonSign.Pos), error = errNumberExpected)

    var conf = defaultJsonReaderConf
    conf.exponentDigitsLimit = 5
    testScanNumber("-0.2e+123456", JsonNumber[uint64](sign: JsonSign.Neg,
      integer: 0, fraction: "2", expSign: JsonSign.Pos, exponent: 12345),
        error = errExpDigitLimit, conf = conf)

  test "scanValue string":
    testScanValue("\"hello world\"", "\"hello world\"")
    testScanValue("-0.2e+9", "-0.2e+9")
    testScanValue("true", "true")
    testScanValue("false", "false")
    testScanValue("null", "null")
    testScanValue("[\"abc\", 1234.456, true, false , null ]",
      "[\"abc\",1234.456,true,false,null]")
    testScanValue("""{ "apple" : 1 , "banana" : true }""",
      """{"apple":1,"banana":true}""")

    testScanValue("b", "", error = errUnknownChar)
    testScanValue("[,", "[", error = errMissingFirstElement)
    testScanValue("{,", "{", error = errMissingFirstElement)

    testScanValue("[,", "[", error = errMissingFirstElement,
      flags = {JsonReaderFlag.trailingComma})
    testScanValue("{,", "{", error = errMissingFirstElement,
      flags = {JsonReaderFlag.trailingComma})

    testScanValue("{\"a\":1,}", "{\"a\":1", flags = {}, error = errTrailingComma)
    testScanValue("[1,]", "[1", flags = {}, error = errTrailingComma)

    testScanValue("{\"a\":1,}", "{\"a\":1}")
    testScanValue("[1,]", "[1]")

    testScanValue("[]", "[]")
    testScanValue("{}", "{}")

    var conf = defaultJsonReaderConf
    conf.arrayElementsLimit = 3
    conf.objectMembersLimit = 3

    testScanValue("[1,2,3,4]", "[1,2,3,", error = errArrayElementsLimit, conf = conf)
    testScanValue("{\"a\":1, \"b\":2, \"C\":3, \"d\": 4}",
      "{\"a\":1,\"b\":2,\"C\":3,", error = errObjectMembersLimit, conf = conf)

    testScanValue("[[[1]]]", "[[[1]]]")

    conf.nestedDepthLimit = 3
    testScanValue("[[[[1]]]]", "[[[[", error = errNestedDepthLimit, conf = conf)
    testScanValue("[ { \"a\": [ { \"b\": 3}] } ]", "[{\"a\":[{\"b\":",
      error = errNestedDepthLimit, conf = conf)

    testScanValue("{ \"a\": 1234.567 // comments\n }",
      "{\"a\":1234.567", flags = {}, error = errCommentNotAllowed)
    testScanValue("{ \"a\": 1234.567 // comments\n }",
      "{\"a\":1234.567}")

  test "scanValue JsonVoid":
    testScanValue("\"hello world\"", JsonVoid())
    testScanValue("-0.2e+9", JsonVoid())
    testScanValue("true", JsonVoid())
    testScanValue("false", JsonVoid())
    testScanValue("null", JsonVoid())
    testScanValue("[\"abc\", 1234.456, true, false , null ]", JsonVoid())
    testScanValue("""{ "apple" : 1 , "banana" : true }""", JsonVoid())

    testScanValue("b", JsonVoid(), error = errUnknownChar)
    testScanValue("[,", JsonVoid(), error = errMissingFirstElement)
    testScanValue("{,", JsonVoid(), error = errMissingFirstElement)

    testScanValue("[,", JsonVoid(), error = errMissingFirstElement,
      flags = {JsonReaderFlag.trailingComma})
    testScanValue("{,", JsonVoid(), error = errMissingFirstElement,
      flags = {JsonReaderFlag.trailingComma})

    testScanValue("{\"a\":1,}", JsonVoid(), flags = {}, error = errTrailingComma)
    testScanValue("[1,]", JsonVoid(), flags = {}, error = errTrailingComma)

    testScanValue("{\"a\":1,}", JsonVoid())
    testScanValue("[1,]", JsonVoid())

    testScanValue("[]", JsonVoid())
    testScanValue("{}", JsonVoid())

    var conf = defaultJsonReaderConf
    conf.arrayElementsLimit = 3
    conf.objectMembersLimit = 3

    testScanValue("[1,2,3,4]", JsonVoid(), error = errArrayElementsLimit, conf = conf)
    testScanValue("{\"a\":1, \"b\":2, \"C\":3, \"d\": 4}",
      JsonVoid(), error = errObjectMembersLimit, conf = conf)

    testScanValue("[[[1]]]", JsonVoid())

    conf.nestedDepthLimit = 3
    testScanValue("[[[[1]]]]", JsonVoid(), error = errNestedDepthLimit, conf = conf)
    testScanValue("[ { \"a\": [ { \"b\": 3}] } ]",
      JsonVoid(), error = errNestedDepthLimit, conf = conf)

    testScanValue("{ \"a\": 1234.567 // comments\n }",
      JsonVoid(), flags = {}, error = errCommentNotAllowed)
    testScanValue("{ \"a\": 1234.567 // comments\n }",
      JsonVoid())

    testScanValue("{ \"a\": 1234.567 /* comments */ }",
      JsonVoid(), flags = {}, error = errCommentNotAllowed)
    testScanValue("{ \"a\": 1234.567 /* comments */ }",
      JsonVoid())

  test "scanValue JsonValueRef[uint64]":
    proc jsonString(x: string): JsonValueRef[uint64] =
      JsonValueRef[uint64](kind: JsonValueKind.String, strVal: x)

    proc jsonNumber(sign: JsonSign, integer: uint64,
      fraction: string, expSign: JsonSign, exponent: uint64): JsonValueRef[uint64] =
      JsonValueRef[uint64](kind: JsonValueKind.Number,
        numVal: JsonNumber[uint64](
          sign: sign,
          integer: integer,
          fraction: fraction,
          expSign: expSign,
          exponent: exponent
        )
      )

    proc jsonNumber(integer: uint64, fraction: string = ""): JsonValueRef[uint64] =
      JsonValueRef[uint64](kind: JsonValueKind.Number,
        numVal: JsonNumber[uint64](
          integer: integer,
          fraction: fraction,
        )
      )

    proc jsonBool(x: bool): JsonValueRef[uint64] =
      JsonValueRef[uint64](kind: JsonValueKind.Bool, boolVal: x)

    proc jsonNull(): JsonValueRef[uint64] =
      JsonValueRef[uint64](kind: JsonValueKind.Null)

    testScanValue("\"hello world\"", jsonString("hello world"))
    testScanValue("-0.2e+9", jsonNumber(JsonSign.Neg, 0, "2", JsonSign.Pos, 9))

    testScanValue("true", jsonBool(true))
    testScanValue("false", jsonBool(false))
    testScanValue("null", jsonNull())

    testScanValue("[\"abc\", 1234.456, true, false , null ]",
      JsonValueRef[uint64](kind: JsonValueKind.Array, arrayVal: @[
        jsonString("abc"),
        jsonNumber(1234, "456"),
        jsonBool(true),
        jsonBool(false),
        jsonNull(),
      ]))


    testScanValue("""{ "apple" : "hello" , "banana" : true }""",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("apple", jsonString("hello")),
          ("banana", jsonBool(true))
        ].toOrderedTable
      ))

    testScanValue("b", JsonValueRef[uint64](nil), error = errUnknownChar)
    testScanValue("[,", JsonValueRef[uint64](kind: JsonValueKind.Array),
      error = errMissingFirstElement)
    testScanValue("{,", JsonValueRef[uint64](kind: JsonValueKind.Object),
      error = errMissingFirstElement)

    testScanValue("[,", JsonValueRef[uint64](kind: JsonValueKind.Array),
      error = errMissingFirstElement, flags = {JsonReaderFlag.trailingComma})
    testScanValue("{,", JsonValueRef[uint64](kind: JsonValueKind.Object),
      error = errMissingFirstElement, flags = {JsonReaderFlag.trailingComma})

    testScanValue("{\"a\": true,}",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [("a", jsonBool(true))].toOrderedTable
      ), flags = {}, error = errTrailingComma)

    testScanValue("[true,]",
      JsonValueRef[uint64](kind: JsonValueKind.Array,
        arrayVal: @[
          jsonBool(true)
        ]
      ), flags = {}, error = errTrailingComma)

    testScanValue("{\"a\": true,}",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [("a", jsonBool(true))].toOrderedTable
      ))

    testScanValue("[true,]",
      JsonValueRef[uint64](kind: JsonValueKind.Array,
        arrayVal: @[
          jsonBool(true)
        ]
      ))

    testScanValue("[]", JsonValueRef[uint64](kind: JsonValueKind.Array))
    testScanValue("{}", JsonValueRef[uint64](kind: JsonValueKind.Object))


    var conf = defaultJsonReaderConf
    conf.arrayElementsLimit = 3
    conf.objectMembersLimit = 3

    testScanValue("[1,2,3,4]", JsonValueRef[uint64](kind: JsonValueKind.Array,
      arrayVal: @[
        jsonNumber(1),
        jsonNumber(2),
        jsonNumber(3),
      ]), error = errArrayElementsLimit, conf = conf)

    testScanValue("{\"a\":1, \"b\":2, \"C\":3, \"d\": 4}",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("a", jsonNumber(1)),
          ("b", jsonNumber(2)),
          ("C", jsonNumber(3)),
        ].toOrderedTable
      ), error = errObjectMembersLimit, conf = conf)

    testScanValue("[[[1]]]", JsonValueRef[uint64](kind: JsonValueKind.Array,
      arrayVal: @[
        JsonValueRef[uint64](kind: JsonValueKind.Array,
        arrayVal: @[
          JsonValueRef[uint64](kind: JsonValueKind.Array,
          arrayVal: @[
            jsonNumber(1)
          ])
        ])
      ])
    )

    conf.nestedDepthLimit = 3
    testScanValue("[[[[1]]]]", JsonValueRef[uint64](kind: JsonValueKind.Array,
      arrayVal: @[
        JsonValueRef[uint64](kind: JsonValueKind.Array,
        arrayVal: @[
          JsonValueRef[uint64](kind: JsonValueKind.Array,
          arrayVal: @[
            JsonValueRef[uint64](kind: JsonValueKind.Array, arrayVal: @[
              JsonValueRef[uint64](nil)
            ])
          ])
        ])
      ]), error = errNestedDepthLimit, conf = conf)

    testScanValue("[ { \"a\": [ { \"b\": 3}] } ]",
      JsonValueRef[uint64](kind: JsonValueKind.Array,
      arrayVal: @[
        JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("a", JsonValueRef[uint64](kind: JsonValueKind.Array,
            arrayVal: @[
              JsonValueRef[uint64](kind: JsonValueKind.Object)
            ])
          )
        ].toOrderedTable)
      ]), error = errNestedDepthLimit, conf = conf)

    testScanValue("{ \"a\": 1234.567 // comments\n }",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("a", jsonNumber(1234, "567"))
        ].toOrderedTable
      ), flags = {}, error = errCommentNotAllowed)

    testScanValue("{ \"a\": 1234.567 // comments\n }",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("a", jsonNumber(1234, "567"))
        ].toOrderedTable
      ))

    testScanValue("{ \"a\": 1234.567 /* comments */ }",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("a", jsonNumber(1234, "567"))
        ].toOrderedTable
      ), flags = {}, error = errCommentNotAllowed)

    testScanValue("{ \"a\": 1234.567 /* comments */ }",
      JsonValueRef[uint64](kind: JsonValueKind.Object,
        objVal: [
          ("a", jsonNumber(1234, "567"))
        ].toOrderedTable
      ))

  test "spec test cases":
    testScanNumber("20E1", "20E1")
    testScanNumber("20E1", JsonVoid())
    testScanNumber("20E1", JsonNumber[uint64](integer:20, exponent:1))

    testScanNumber("1.0000005", "1.0000005")
    testScanNumber("1.0000005", JsonVoid())

    # both fraction and exponent support leading zeros
    # the meaning of leading zeros in fraction is clear.
    # but the meaning of leading zeros in exponent is questionable or even needed.
    testScanNumber("1.0000005E004",
      JsonNumber[string](
        integer:"1",
        fraction:"0000005",
        exponent:"004"
      ))

    testScanNumber("1.0000005E004",
      JsonNumber[uint64](
        integer:1,
        fraction:"0000005",
        exponent:4
      ))

    testScanValue("[-2.]", "[-2.", error = errEmptyFraction)
    testScanNumber("-2.", "-2.", error = errEmptyFraction)
    testScanNumber("0.e1", "0.", error = errEmptyFraction)
    testScanNumber("2.e+3", "2.", error = errEmptyFraction)
    testScanNumber("2.e-3", "2.", error = errEmptyFraction)
    testScanNumber("2.e3", "2.", error = errEmptyFraction)
    testScanNumber("1.", "1.", error = errEmptyFraction)

    testScanValue("[+1]", "[", flags = {}, error = errIntPosSign)
    testScanValue("[+1]", "[+1]")
    testScanValue("[1+2]", "[1", error = errCommaExpected)

    testScanValue("[1 true]", "[1", error = errCommaExpected)
    testScanValue("[1,,2]", "[1,", error = errValueExpected)
    testScanValue("[3 [4]]", "[3", error = errCommaExpected)

    testScanValue("{\"a\":true,,\"c\":false}", "{\"a\":true,", error = errValueExpected)
    testScanValue("{\"a\":true \"c\":false}", "{\"a\":true", error = errCommaExpected)

    testScanValue("{\"a\":true ", "{\"a\":true", error = errCurlyRiExpected)

    for c in '\x00'..'\x1F':
      if c notin {'\r', '\n'}:
        testScanString("\"a" & c & "a\"", "a", error = errEscapeControlChar)

    testScanValue("{123:true}", "{", error = errStringExpected)
    testScanValue("{123:true}", JsonVoid(), error = errStringExpected)
    testScanValue("{123:true}", JsonValueRef[uint64](kind: JsonValueKind.Object), error = errStringExpected)

    testScanValue("{\"123:true}", "{\"123:true}", error = errUnexpectedEof)
