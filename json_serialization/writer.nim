import
  typetraits,
  faststreams/output_stream, serialization

type
  JsonWriterState = enum
    RecordExpected
    RecordStarted
    AfterField

  JsonWriter* = object
    stream*: OutputStreamVar
    hasTypeAnnotations: bool
    hasPrettyOutput*: bool # read-only
    nestingLevel*: int     # read-only
    state: JsonWriterState

proc init*(T: type JsonWriter, stream: OutputStreamVar,
           pretty = false, typeAnnotations = false): T =
  result.stream = stream
  result.hasPrettyOutput = pretty
  result.hasTypeAnnotations = typeAnnotations
  result.nestingLevel = if pretty: 0 else: -1
  result.state = RecordExpected

proc writeImpl(w: var JsonWriter, value: auto)

template writeValue*(w: var JsonWriter, v: auto) =
  writeImpl(w, v)

proc beginRecord*(w: var JsonWriter, T: type)
proc beginRecord*(w: var JsonWriter)

template append(x: untyped) =
  w.stream.append x

template indent =
  for i in 0 ..< w.nestingLevel:
    append ' '

proc writeFieldName*(w: var JsonWriter, name: string) =
  # this is implemented as a separate proc in order to
  # keep the code bloat from `writeField` to a minimum
  assert w.state != RecordExpected

  if w.state == AfterField:
    append ','

  if w.hasPrettyOutput:
    append '\n'

  indent()

  append '"'
  append name
  append '"'
  append ':'
  if w.hasPrettyOutput: append ' '

  w.state = RecordExpected

proc writeField*(w: var JsonWriter, name: string, value: auto) =
  mixin writeValue

  w.writeFieldName(name)
  w.writeValue(value)

  w.state = AfterField

proc beginRecord*(w: var JsonWriter) =
  assert w.state == RecordExpected

  append '{'
  if w.hasPrettyOutput:
    w.nestingLevel += 2

  w.state = RecordStarted

proc beginRecord*(w: var JsonWriter, T: type) =
  w.beginRecord()
  if w.hasTypeAnnotations: w.writeField("$type", typetraits.name(T))

proc endRecord*(w: var JsonWriter) =
  assert w.state != RecordExpected

  if w.hasPrettyOutput:
    append '\n'
    w.nestingLevel -= 2
    indent()

  append '}'

template endRecordField*(w: var JsonWriter) =
  endRecord(w)
  w.state = AfterField

proc writeArray[T](w: var JsonWriter, elements: openarray[T]) =
  mixin writeValue

  append '['
  for i, e in elements:
    if i != 0: append ','
    w.state = RecordExpected
    w.writeValue(e)
  append ']'

proc writeImpl(w: var JsonWriter, value: auto) =
  template addChar(c) =
    append c

  when value is string:
    addChar '"'

    template addPrefixSlash(c) =
      addChar '\\'
      addChar c

    for c in value:
      case c
      of '\L': addPrefixSlash 'n'
      of '\b': addPrefixSlash 'b'
      of '\f': addPrefixSlash 'f'
      of '\t': addPrefixSlash 't'
      of '\r': addPrefixSlash 'r'
      of '"' : addPrefixSlash '\"'
      of '\0'..'\7':
        append "\\u000"
        append char(ord('0') + ord(c))
      of '\14'..'\31':
        append "\\u00"
        # TODO: Should this really use a decimal representation?
        # Or perhaps $ord(c) returns hex?
        # This is potentially a bug in Nim's json module.
        # In any case, we can call appendNumber here.
        append $ord(c)
      of '\\': addPrefixSlash '\\'
      else: addChar c

    addChar '"'

  elif value is bool:
    append if value: "true" else: "false"
  elif value is enum:
    w.stream.appendNumber ord(value)
  elif value is SomeInteger:
    w.stream.appendNumber value
  elif value is SomeFloat:
    append $value
  elif value is (seq or array):
    w.writeArray(value)
  elif value is (object or tuple):
    w.beginRecord(type(value))
    value.serializeFields(k, v):
      w.writeField k, v
    w.endRecord()
  else:
    const typeName = typetraits.name(value.type)
    {.fatal: "Failed to convert to JSON an unsupported type: " & typeName.}

proc toJson*(v: auto, pretty = false, typeAnnotations = false): string =
  mixin writeValue

  var s = init OutputStream
  var w = JsonWriter.init(s, pretty, typeAnnotations)
  w.writeValue v
  return s.getOutput(string)

