# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  strutils, os

# `dedent` exists in newer Nim version and doesn't behave the same
func test_dedent*(s: string): string =
  var
    s = s.strip(leading = false)
    minIndent = high(int)
  for l in s.splitLines:
    let indent = count(l, ' ')
    if indent == 0: continue
    if indent < minIndent: minIndent = indent
  s.unindent(minIndent)

proc pathRelativeTo*(fileName, base: string): string =
  try:
    relativePath(fileName, base)
  except Exception as err:
    raise newException(Defect, err.msg)

const
  parsingPath* = "tests/test_vectors/test_parsing"
  transformPath* = "tests/test_vectors/test_transform"

const
  allowedToFail* = [
    "string_1_escaped_invalid_codepoint.json",
    "string_3_escaped_invalid_codepoints.json",
    "i_number_huge_exp.json",
    "i_string_1st_surrogate_but_2nd_missing.json",
    "i_string_incomplete_surrogate_and_escape_valid.json",
    "i_string_invalid_lonely_surrogate.json",
    "i_string_invalid_surrogate.json",
    "i_string_inverted_surrogates_U+1D11E.json",
    "i_string_UTF-16LE_with_BOM.json",
    "i_string_utf16BE_no_BOM.json",
    "i_string_utf16LE_no_BOM.json",
    "i_structure_UTF-8_BOM_empty_object.json",
  ]
