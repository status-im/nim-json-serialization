import
  strutils

# `dedent` exists in newer nim version
# and doesn't behave the same
proc test_dedent*(s: string): string =
  var s = s.strip(leading = false)
  var minIndent = high(int)
  for l in s.splitLines:
    let indent = count(l, ' ')
    if indent == 0: continue
    if indent < minIndent: minIndent = indent
  result = s.unindent(minIndent)

