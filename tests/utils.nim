import
  strutils

proc dedent*(s: string): string =
  var s = s.strip(leading = false)
  var minIndent = 99999999999
  for l in s.splitLines:
    let indent = count(l, ' ')
    if indent == 0: continue
    if indent < minIndent: minIndent = indent
  result = s.unindent(minIndent)

