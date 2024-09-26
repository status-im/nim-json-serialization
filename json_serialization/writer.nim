# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[json, typetraits],
  faststreams/[outputs, textio],
  serialization,
  "."/[format, types]

export
  outputs, format, types, JsonString, DefaultFlavor

type
  JsonWriterState = enum
    RecordExpected
    RecordStarted
    AfterField

  JsonWriter*[Flavor = DefaultFlavor] = object
    stream*: OutputStream
    hasTypeAnnotations: bool
    hasPrettyOutput*: bool # read-only
    nestingLevel*: int     # read-only
    state: JsonWriterState

Json.setWriter JsonWriter,
               PreferredOutput = string

func init*(W: type JsonWriter, stream: OutputStream,
           pretty = false, typeAnnotations = false): W =
  W(stream: stream,
    hasPrettyOutput: pretty,
    hasTypeAnnotations: typeAnnotations,
    nestingLevel: if pretty: 0 else: -1,
    state: RecordExpected)

proc beginRecord*(w: var JsonWriter, T: type)
proc beginRecord*(w: var JsonWriter)
proc writeValue*(w: var JsonWriter, value: auto) {.gcsafe, raises: [IOError].}

# If it's an optional field, test for it's value before write something.
# If it's non optional field, the field is always written.
template shouldWriteObjectField*[FieldType](field: FieldType): bool = true

template append(x: untyped) =
  write w.stream, x

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

proc writeField*(
    w: var JsonWriter, name: string, value: auto) {.raises: [IOError].} =
  mixin writeValue
  mixin flavorOmitsOptionalFields, shouldWriteObjectField

  type
    Writer = typeof w
    Flavor = Writer.Flavor

  when flavorOmitsOptionalFields(Flavor):
    if shouldWriteObjectField(value):
      w.writeFieldName(name)
      w.writeValue(value)
      w.state = AfterField
  else:
    w.writeFieldName(name)
    w.writeValue(value)
    w.state = AfterField

template fieldWritten*(w: var JsonWriter) =
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

iterator stepwiseArrayCreation*[C](w: var JsonWriter, collection: C): auto =
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
    yield e
    first = false

  if w.hasPrettyOutput:
    append '\n'
    w.nestingLevel -= 2
    indent()

  append ']'

proc writeIterable*(w: var JsonWriter, collection: auto) =
  mixin writeValue
  for e in w.stepwiseArrayCreation(collection):
    w.writeValue(e)

proc writeArray*[T](w: var JsonWriter, elements: openArray[T]) =
  writeIterable(w, elements)

template writeObject*(w: var JsonWriter, T: type, body: untyped) =
  w.beginRecord(T)
  body
  w.endRecord()

template writeObject*(w: var JsonWriter, body: untyped) =
  w.beginRecord()
  body
  w.endRecord()

# this construct catches `array[N, char]` which otherwise won't decompose into
# openArray[char] - we treat any array-like thing-of-characters as a string in
# the output
template isStringLike(v: string|cstring|openArray[char]|seq[char]): bool = true
template isStringLike[N](v: array[N, char]): bool = true
template isStringLike(v: auto): bool = false

template writeObjectField*[FieldType, RecordType](w: var JsonWriter,
                                                  record: RecordType,
                                                  fieldName: static string,
                                                  field: FieldType) =
  mixin writeFieldIMPL, writeValue

  w.writeFieldName(fieldName)
  when RecordType is tuple:
    w.writeValue(field)
  else:
    type R = type record
    w.writeFieldIMPL(FieldTag[R, fieldName], field, record)

proc writeRecordValue*(w: var JsonWriter, value: auto)
                      {.gcsafe, raises: [IOError].} =
  mixin enumInstanceSerializedFields, writeObjectField
  mixin flavorOmitsOptionalFields, shouldWriteObjectField

  type RecordType = type value
  w.beginRecord RecordType
  value.enumInstanceSerializedFields(fieldName, fieldValue):
    when fieldValue isnot JsonVoid:
      type
        Writer = typeof w
        Flavor = Writer.Flavor
      when flavorOmitsOptionalFields(Flavor):
        if shouldWriteObjectField(fieldValue):
          writeObjectField(w, value, fieldName, fieldValue)
          w.state = AfterField
      else:
        writeObjectField(w, value, fieldName, fieldValue)
        w.state = AfterField
    else:
      discard fieldName
  w.endRecord()

proc writeNumber*[F,T](w: var JsonWriter[F], value: JsonNumber[T]) =
  if value.sign == JsonSign.Neg:
    append '-'

  when T is uint64:
    w.stream.writeText value.integer
  else:
    append value.integer

  if value.fraction.len > 0:
    append '.'
    append value.fraction

  template writeExp(body: untyped) =
    when T is uint64:
      if value.exponent > 0:
        body
    else:
      if value.exponent.len > 0:
        body

  writeExp:
    append 'e'
    if value.sign == JsonSign.Neg:
      append '-'
    when T is uint64:
      w.stream.writeText value.exponent
    else:
      append value.exponent

proc writeJsonValueRef*[F,T](w: var JsonWriter[F], value: JsonValueRef[T]) =
  if value.isNil:
    append "null"
    return

  case value.kind
  of JsonValueKind.String:
    w.writeValue(value.strVal)
  of JsonValueKind.Number:
    w.writeNumber(value.numVal)
  of JsonValueKind.Object:
    w.beginRecord typeof(value)
    for k, v in value.objVal:
      w.writeField(k, v)
    w.endRecord()
  of JsonValueKind.Array:
    w.writeArray(value.arrayVal)
  of JsonValueKind.Bool:
    if value.boolVal:
      append "true"
    else:
      append "false"
  of JsonValueKind.Null:
    append "null"

template writeEnumImpl(w: var JsonWriter, value, enumRep) =
  mixin writeValue
  when enumRep == EnumAsString:
    w.writeValue $value
  elif enumRep == EnumAsNumber:
    w.stream.writeText(value.int)
  elif enumRep == EnumAsStringifiedNumber:
    w.writeValue $value.int

template writeValue*(w: var JsonWriter, value: enum) =
  # We extract this as a template because
  # if we put it into `proc writeValue` below
  # the Nim compiler generic cache mechanism
  # will mess up with the compile time
  # conditional selection
  type Flavor = type(w).Flavor
  writeEnumImpl(w, value, Flavor.flavorEnumRep())

proc writeValue*(w: var JsonWriter, value: auto) {.gcsafe, raises: [IOError].} =
  mixin writeValue

  when value is JsonNode:
    append if w.hasPrettyOutput: value.pretty
           else: $value

  elif value is JsonString:
    append string(value)

  elif value is JsonVoid:
    discard

  elif value is JsonNumber:
    w.writeNumber(value)

  elif value is JsonValueRef:
    w.writeJsonValueRef(value)

  elif value is ref:
    if value == nil:
      append "null"
    else:
      writeValue(w, value[])

  elif isStringLike(value):
    when value is cstring:
      if value == nil:
        append "null"
        return

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

  elif value is range:
    when low(typeof(value)) < 0:
      w.stream.writeText int64(value)
    else:
      w.stream.writeText uint64(value)

  elif value is SomeInteger:
    w.stream.writeText value

  elif value is SomeFloat:
    # TODO Implement writeText for floats
    #      to avoid the allocation here:
    append $value

  elif value is (seq or array or openArray) or
      (value is distinct and distinctBase(value) is (seq or array or openArray)):
    when value is distinct:
      w.writeArray(distinctBase value)
    else:
      w.writeArray(value)

  elif value is (distinct or object or tuple):
    mixin flavorUsesAutomaticObjectSerialization

    type Flavor = JsonWriter.Flavor
    const isAutomatic =
      flavorUsesAutomaticObjectSerialization(Flavor)

    when not isAutomatic:
      const typeName = typetraits.name(type value)
      {.error: "Please override writeValue for the " & typeName & " type (or import the module where the override is provided)".}

    when value is distinct:
      writeRecordValue(w, distinctBase(value, recursive = false))
    else:
      writeRecordValue(w, value)
  else:
    const typeName = typetraits.name(value.type)
    {.fatal: "Failed to convert to JSON an unsupported type: " & typeName.}

proc toJson*(v: auto, pretty = false, typeAnnotations = false): string =
  mixin writeValue

  var
    s = memoryOutput()
    w = JsonWriter[DefaultFlavor].init(s, pretty, typeAnnotations)
  w.writeValue v
  s.getOutput(string)

template serializesAsTextInJson*(T: type[enum]) =
  template writeValue*(w: var JsonWriter, val: T) =
    w.writeValue $val

template configureJsonSerialization*(
    T: type[enum], enumRep: static[EnumRepresentation]) =
  proc writeValue*(w: var JsonWriter,
                   value: T) {.gcsafe, raises: [IOError].} =
    writeEnumImpl(w, value, enumRep)

template configureJsonSerialization*(Flavor: type,
                        T: type[enum],
                        enumRep: static[EnumRepresentation]) =
  when Flavor is Json:
    proc writeValue*(w: var JsonWriter[DefaultFlavor],
                     value: T) {.gcsafe, raises: [IOError].} =
      writeEnumImpl(w, value, enumRep)
  else:
    proc writeValue*(w: var JsonWriter[Flavor],
                     value: T) {.gcsafe, raises: [IOError].} =
      writeEnumImpl(w, value, enumRep)
