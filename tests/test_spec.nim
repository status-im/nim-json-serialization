# json-serialization
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[strutils, os],
  faststreams,
  ./utils

# we want to test lexer internals
# hence use include instead of import
include
  ../json_serialization/lexer

proc yCase(fileName, name: string): bool {.raises:[IOError].} =
  var stream = memFileInput(fileName)
  var lex = init(JsonLexer, stream)
  var value: string
  lex.scanValue(value)
  if lex.err != errNone:
    debugEcho name, " FAIL ", lex.err
    debugEcho value
    return false
  true

proc nCase(fileName, name: string): bool {.raises:[IOError].} =
  var stream = memFileInput(fileName)
  var lex = init(JsonLexer, stream, {})
  var value: string
  lex.scanValue(value)
  discard lex.nonws()
  if lex.ok and lex.readable:
    # contains garbage
    return true
  if lex.err == errNone:
    debugEcho name, " FAIL, should error"
    debugEcho value
    return false
  true

for fileName in walkDirRec(parsingPath):
  let (_, name) = fileName.splitPath()
  if name.startsWith("y_"):
    doAssert yCase(fileName, name)
  elif name.startsWith("n_"):
    doAssert nCase(fileName, name)
  # test cases starts with i_ are allowed to
  # fail or success depending on the implementation details
  elif name.startsWith("i_"):
    if name notin allowedToFail:
      doAssert yCase(fileName, name)

for fileName in walkDirRec(transformPath):
  let (_, name) = fileName.splitPath()
  if name notin allowedToFail:
    doAssert yCase(fileName, name)
