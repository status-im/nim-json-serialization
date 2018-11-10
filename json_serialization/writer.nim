import
  typetraits, serialization/streams

type
  JsonWriterState = enum
    RecordExpected
    RecordStarted
    AfterField

  JsonWriter*[Stream] = object
    stream*: Stream
    hasTypeAnnotations: bool
    hasPrettyOutput*: bool # read-only
    nestingLevel*: int     # read-only
    state: JsonWriterState

  StringJsonWriter* = JsonWriter[StringStream]

proc init*(T: type JsonWriter, pretty = false, typeAnnotations = false): T =
  init result.stream
  result.hasPrettyOutput = pretty
  result.hasTypeAnnotations = typeAnnotations
  result.nestingLevel = if pretty: 0 else: -1
  result.state = RecordExpected

proc writeImpl(w: var JsonWriter, value: auto)

template writeValue*(w: var JsonWriter, v: auto) =
  writeImpl(w, v)

proc beginRecord*(w: var JsonWriter, T: type)
proc beginRecord*(w: var JsonWriter)

template indent(w: var JsonWriter) =
  for i in 0 ..< w.nestingLevel:
    w.stream.append ' '

proc writeFieldName*(w: var JsonWriter, name: string) =
  # this is implemented as a separate proc in order to
  # keep the code bloat from `writeField` to a minimum
  assert w.state != RecordExpected

  if w.state == AfterField:
    w.stream.append ','

  if w.hasPrettyOutput:
    w.stream.append '\n'

  w.indent()

  w.stream.append '"'
  w.stream.append name
  w.stream.append '"'
  w.stream.append ':'
  if w.hasPrettyOutput: w.stream.append ' '

proc writeField*(w: var JsonWriter, name: string, value: auto) =
  mixin writeValue

  w.writeFieldName(name)

  w.state = RecordExpected
  w.writeValue(value)

  w.state = AfterField

proc beginRecord*(w: var JsonWriter) =
  assert w.state == RecordExpected

  w.stream.append '{'
  if w.hasPrettyOutput:
    w.nestingLevel += 2

  w.state = RecordStarted

proc beginRecord*(w: var JsonWriter, T: type) =
  w.beginRecord()
  if w.hasTypeAnnotations: w.writeField("$type", typetraits.name(T))

proc endRecord*(w: var JsonWriter) =
  assert w.state != RecordExpected

  if w.hasPrettyOutput:
    w.stream.append '\n'
    w.nestingLevel -= 2
    w.indent()

  w.stream.append '}'
  w.state = RecordExpected

proc writeArray[T](w: var JsonWriter, elements: openarray[T]) =
  mixin writeValue

  w.stream.append '['
  for i, e in elements:
    if i != 0: w.stream.append ','
    w.state = RecordExpected
    w.writeValue(e)
  w.stream.append ']'

proc writeImpl(w: var JsonWriter, value: auto) =
  template addChar(c) =
    w.stream.append c

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
        w.stream.append "\\u000"
        w.stream.append char(ord('0') + ord(c))
      of '\14'..'\31':
        w.stream.append "\\u00"
        # TODO: Should this really use a decimal representation?
        # Or perhaps $ord(c) returns hex?
        # This is potentially a bug in Nim's json module.
        # In any case, we can call appendNumber here.
        w.stream.append $ord(c)
      of '\\': addPrefixSlash '\\'
      else: addChar c

    addChar '"'

  elif value is bool:
    w.stream.append if value: "true" else: "false"
  elif value is enum:
    w.stream.appendNumber ord(value)
  elif value is SomeInteger:
    w.stream.appendNumber value
  elif value is SomeFloat:
    w.stream.append $value
  elif value is (seq or array):
    w.writeArray(value)
  elif value is (object or tuple):
    w.beginRecord(type(value))
    # TODO: this won't handle case objects
    # introduce and use `value.deserializePairs(k, v):`
    for k, v in value.fieldPairs:
      w.writeField(k, v)
    w.endRecord()
  else:
    const typeName = typetraits.name(value.type)
    {.error: "Failed to convert to JSON an unsupported type: " & typeName.}

template getOutput*(w: JsonWriter): auto =
  w.stream.getOutput

