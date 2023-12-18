import strutils

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
