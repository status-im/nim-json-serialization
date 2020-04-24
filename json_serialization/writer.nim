import
  typetraits,
  faststreams/output_stream, serialization, json

type
  JsonWriterState = enum
    RecordExpected
    RecordStarted
    AfterField

  JsonWriter* = object
    stream*: OutputStream
    hasTypeAnnotations: bool
    hasPrettyOutput*: bool # read-only
    nestingLevel*: int     # read-only
    state: JsonWriterState

  JsonString* = distinct string

proc init*(T: type JsonWriter, stream: OutputStream,
           pretty = false, typeAnnotations = false): T =
  result.stream = stream
  result.hasPrettyOutput = pretty
  result.hasTypeAnnotations = typeAnnotations
  result.nestingLevel = if pretty: 0 else: -1
  result.state = RecordExpected

proc beginRecord*(w: var JsonWriter, T: type)
proc beginRecord*(w: var JsonWriter)
proc writeValue*(w: var JsonWriter, value: auto)

template append(x: untyped) =
  w.stream.append x

template indent =
  for i in 0 ..< w.nestingLevel:
    append ' '

template `$`*(s: JsonString): string =
  string(s)

proc writeFieldName*(w: var JsonWriter, name: string) =
  # this is implemented as a separate proc in order to
  # keep the code bloat from `writeField` to a minimum
  doAssert w.state != RecordExpected

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
  doAssert w.state == RecordExpected

  append '{'
  if w.hasPrettyOutput:
    w.nestingLevel += 2

  w.state = RecordStarted

proc beginRecord*(w: var JsonWriter, T: type) =
  w.beginRecord()
  if w.hasTypeAnnotations: w.writeField("$type", typetraits.name(T))

proc endRecord*(w: var JsonWriter) =
  doAssert w.state != RecordExpected

  if w.hasPrettyOutput:
    append '\n'
    w.nestingLevel -= 2
    indent()

  append '}'

template endRecordField*(w: var JsonWriter) =
  endRecord(w)
  w.state = AfterField

proc writeIterable*(w: var JsonWriter, collection: auto) =
  mixin writeValue

  append '['

  if w.hasPrettyOutput:
    append '\n'
    w.nestingLevel += 2
    indent()

  var first = true
  for e in collection:
    if not first:
      append ','
      if w.hasPrettyOutput:
        append '\n'
        indent()

    w.state = RecordExpected
    w.writeValue(e)
    first = false

  if w.hasPrettyOutput:
    append '\n'
    w.nestingLevel -= 2
    indent()

  append ']'

proc writeArray*[T](w: var JsonWriter, elements: openarray[T]) =
  writeIterable(w, elements)

# this construct catches `array[N, char]` which otherwise won't decompose into
# openArray[char] - we treat any array-like thing-of-characters as a string in
# the output
template isStringLike(v: string|cstring|openArray[char]|seq[char]): bool = true
template isStringLike[N](v: array[N, char]): bool = true
template isStringLike(v: auto): bool = false

proc writeValue*(w: var JsonWriter, value: auto) =
  mixin enumInstanceSerializedFields, writeValue, writeFieldIMPL

  when value is JsonNode:
    append if w.hasPrettyOutput: value.pretty
           else: $value
  elif value is JsonString:
    append string(value)
  elif value is ref:
    if value == nil:
      append "null"
    else:
      writeValue(w, value[])
  elif isStringLike(value):
    append '"'

    template addPrefixSlash(c) =
      append '\\'
      append c

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
        append $ord(c)
      of '\\': addPrefixSlash '\\'
      else: append c

    append '"'
  elif value is bool:
    append if value: "true" else: "false"
  elif value is enum:
    w.stream.append $ord(value)
  elif value is range:
    when low(value) < 0:
      w.stream.append $int64(value)
    else:
      w.stream.append $uint64(value)
  elif value is SomeInteger:
    w.stream.append $value
  elif value is SomeFloat:
    append $value
  elif value is (seq or array or openArray):
    w.writeArray(value)
  elif value is (object or tuple):
    w.beginRecord(type(value))
    type RecordType = type value
    value.enumInstanceSerializedFields(fieldName, field):
      type FieldType = type field
      w.writeFieldName(fieldName)
      w.writeFieldIMPL(FieldTag[RecordType, fieldName, FieldType], field, value)
      w.state = AfterField
    w.endRecord()
  else:
    const typeName = typetraits.name(value.type)
    {.fatal: "Failed to convert to JSON an unsupported type: " & typeName.}

proc toJson*(v: auto, pretty = false, typeAnnotations = false): string =
  mixin writeValue

  var s = memoryOutput()
  var w = JsonWriter.init(s, pretty, typeAnnotations)
  w.writeValue v
  return s.getOutput(string)

