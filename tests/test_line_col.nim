# json-serialization
# Copyright (c) 2023 Status Research & Development GmbH
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

type
  TestCase = object
    line: int
    col: int
    text: string
    flags: JsonReaderFlags
    conf: JsonReaderConf

func tc(line: int, col: int, text: string): TestCase =
  TestCase(
    line: line,
    col: col,
    text: text,
    flags: defaultJsonReaderFlags,
    conf: defaultJsonReaderConf,
  )

func tc(line: int, col: int, text: string, flags: JsonReaderFlags): TestCase =
  TestCase(
    line: line,
    col: col,
    text: text,
    flags: flags,
    conf: defaultJsonReaderConf,
  )

when false:
  func tc(line: int, col: int, text: string, conf: JsonReaderConf): TestCase =
    TestCase(
      line: line,
      col: col,
      text: text,
      flags: defaultJsonReaderFlags,
      conf: conf,
    )

func noComment(): JsonReaderFlags =
  result = defaultJsonReaderFlags
  result.excl JsonReaderFlag.allowComments

func noTrailingComma(): JsonReaderFlags =
  result = defaultJsonReaderFlags
  result.excl JsonReaderFlag.trailingComma

const testCases = [
  tc(2, 19, """
{
  "a"  : 1234.567 // comments
}
  """, noComment()),

  tc(2, 19, """
{
  "a"  : 1234.567 /* comments */
}
  """, noComment()),

  tc(4, 3, """
{
  "a"  : 1234.567 /* comments
}
  """),

  tc(2, 8, """
{
  "a"  1234.567
}
  """),

  tc(3, 3, """
{

  ,

  """),

  tc(4, 1, """
{
  "a":
  1  ,
}
  """, noTrailingComma()),

  tc(3, 4, """
[

   ,

  """),

  tc(2, 3, """
[
  b
]
  """),

  tc(4, 1, """
[
  1
   ,
]
  """, noTrailingComma()),
]

suite "Test line col":
  for i, tc in testCases:
    test $i:
      var stream = unsafeMemoryInput(tc.text)
      var lex = init(JsonLexer, stream, tc.flags, tc.conf)
      var value: JsonValueRef[uint64]
      lex.scanValue(value)
      check:
        lex.err != errNone
        lex.line == tc.line
        lex.tokenStartCol == tc.col
