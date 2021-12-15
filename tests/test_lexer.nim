import
  unittest,
  ../json_serialization/lexer, ./utils

template expectedToken(token: TokKind, additionalCheck = true) {.dirty.} =
  lexer.next()
  check:
    lexer.tok == token
    bool(additionalCheck)

template lexerTest(name, inputParam: string, expectations) {.dirty.} =
  test name:
    var input = test_dedent(inputParam)
    var stream = unsafeMemoryInput(input)
    var lexer = JsonLexer.init stream
    expectations

template `=~`(lhs, rhs: float): bool =
  abs(lhs - rhs) < 0.01

suite "lexer tests":
  lexerTest "object with simple fields", """
    {
      "x": 10,
      "y": "test"
    }
    """:
    expectedToken tkCurlyLe
    expectedToken tkString,   lexer.strVal == "x"
    expectedToken tkColon
    expectedToken tkInt,      lexer.absIntVal == 10
    expectedToken tkComma
    expectedToken tkString,   lexer.strVal == "y"
    expectedToken tkColon
    expectedToken tkString,   lexer.strVal == "test"
    expectedToken tkCurlyRi
    expectedToken tkEof
    expectedToken tkEof # check that reading past the end is benign

  lexerTest "int literal",    "190":
    expectedToken tkInt,      lexer.absIntVal == 190
    expectedToken tkEof

  lexerTest "int64 literal",  "3568257348920230622":
    expectedToken tkInt,      lexer.absIntVal == 3568257348920230622'u64
    expectedToken tkEof

  lexerTest "float literal",  ".340":
    expectedToken tkFloat,    lexer.floatVal =~ 0.340
    expectedToken tkEof

  lexerTest "string literal", "\"hello\"":
    expectedToken tkString,   lexer.strVal == "hello"
    expectedToken tkEof

  lexerTest "mixed array", "[1, 2.0, \"test\", {}, [],]":
    expectedToken tkBracketLe
    expectedToken tkInt,      lexer.absIntVal == 1
    expectedToken tkComma
    expectedToken tkFloat,    lexer.floatVal =~ 2.0
    expectedToken tkComma
    expectedToken tkString,   lexer.strVal == "test"
    expectedToken tkComma
    expectedToken tkCurlyLe
    expectedToken tkCurlyRi
    expectedToken tkComma
    expectedToken tkBracketLe
    expectedToken tkBracketRi
    expectedToken tkComma
    expectedToken tkBracketRi
    expectedToken tkEof

