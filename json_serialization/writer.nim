# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push gcsafe, raises: [].}

import
  std/[json, typetraits],
  faststreams/[outputs, textio],
  serialization,
  "."/[format, types]

export
  outputs, format, types, JsonString, DefaultFlavor

type
  CollectionKind = enum
    Array
    Object


  JsonWriter*[Flavor = DefaultFlavor] = object
    stream*: OutputStream
    hasTypeAnnotations: bool
    hasPrettyOutput*: bool # read-only
    stack: seq[CollectionKind]
      ## Stack that keeps track of nested arrays/objects
    empty: bool
      ## True before any members / elements have been written to an object / array
    wantName: bool
      ## The next output should be a name (for an object member)

Json.setWriter JsonWriter,
               PreferredOutput = string

template nestingLevel(w: JsonWriter): int =
  w.stack.len * 2

func init*(W: type JsonWriter, stream: OutputStream,
           pretty = false, typeAnnotations = false): W =
  W(stream: stream,
    hasPrettyOutput: pretty,
    hasTypeAnnotations: typeAnnotations)

proc writeValue*[V: not void](w: var JsonWriter, value: V) {.raises: [IOError].}
  ## Write value as JSON, without adornments for arrays and objects.
  ##
  ## See also `writeElement` and `writeMember`.
proc writeElement*[V: not void](w: var JsonWriter, value: V) {.raises: [IOError].}
  ## Write `value` as a JSON element in an array or object member pair, adorning
  ## it with `beginElement`/`endElement` as needed.
proc writeMember*[V: not void](w: var JsonWriter, name: string, value: V) {.raises: [IOError].}
  ## Write `name` and `value` as a JSON member / field of an object.

# If it's an optional field, test for it's value before write something.
# If it's non optional field, the field is always written.
template shouldWriteObjectField*[FieldType](field: FieldType): bool = true

template append(x: untyped) =
  write w.stream, x

template indent =
  if w.hasPrettyOutput:
    append "\n"
    for i in 0 ..< w.nestingLevel:
      append ' '

func inArray(w: JsonWriter): bool =
  w.stack.len > 0 and w.stack[^1] == Array

func inObject(w: JsonWriter): bool =
  w.stack.len > 0 and w.stack[^1] == Object

proc beginElement*(w: var JsonWriter) {.raises: [IOError].} =
  ## Start writing an array element or the value part of an object member.
  ##
  ## Must be closed with a corresponding `endElement`.
  ##
  ## See also `writeElement`, `writeMember`.
  doAssert not w.wantName

  if w.inArray:
    if w.empty:
      w.empty = false
    else:
      append ','

    indent()

proc endElement*(w: var JsonWriter) =
  ## Matching `end` call for `beginElement`
  w.wantName = w.inObject

proc beginObject*(w: var JsonWriter, nested: static bool = false) {.raises: [IOError].} =
  ## Start writing an object, to be followed by member fields.
  ##
  ## Must be closed with a matching `endObject`.
  ##
  ## See also `writeObject`.
  ##
  ## Use `writeMember`, `writeArrayMember`, `writeObjectMember` to add member
  ## fields to the object.
  ##
  ## Use `nested = true` when creating the object nested inside another object
  ## or array, or use `beginObjectElement` / `beginObjectMember`.
  ##
  ## Use `nested = false` (the default) in top-level calls both in `writeValue`
  ## implementations and when streaming.
  when nested:
    w.beginElement()

  append '{'

  w.empty = true
  w.wantName = true

  w.stack.add(Object)

proc beginObject*(w: var JsonWriter, O: type, nested: static bool = false) {.raises: [IOError].} =
  w.beginObject(nested)
  if w.hasTypeAnnotations: w.writeMember("$type", typetraits.name(O))

proc endObject*(w: var JsonWriter, nested: static bool = false) {.raises: [IOError].} =
  doAssert w.stack.pop() == Object

  if not w.empty:
    indent()

  w.empty = false
  append '}'

  when nested:
    w.endElement()

proc beginArray*(w: var JsonWriter, nested: static bool = false) {.raises: [IOError].} =
  when nested:
    w.beginElement()

  append '['

  w.empty = true

  w.stack.add(Array)

proc endArray*(w: var JsonWriter, nested: static bool = false) {.raises: [IOError].} =
  doAssert w.stack.pop() == Array

  if not w.empty:
    indent()

  w.empty = false

  append ']'

  when nested:
    w.endElement()

template writeElement*[T: void](w: var JsonWriter, body: T) =
  w.beginElement()
  body
  w.endElement()

proc writeElement*[V: not void](w: var JsonWriter, value: V) {.raises: [IOError].} =
  mixin writeValue

  w.writeElement:
    w.writeValue(value)

template beginObjectElement*(w: var JsonWriter) =
  ## Begin an object nested inside an array or after a member name
  beginObject(w, nested = true)

template beginObjectElement*(w: var JsonWriter, O: type) =
  ## Begin an object nested inside an array or after a member name
  beginObject(w, O, nested = true)

template endObjectElement*(w: var JsonWriter) = endObject(w, nested = true)

template beginArrayElement*(w: var JsonWriter) = beginArray(w, nested = true)

template endArrayElement*(w: var JsonWriter) = endArray(w, nested = true)

proc writeName*(w: var JsonWriter, name: string) {.raises: [IOError].} =
  ## Write the name part of the member of an object, to be followed by the value
  doAssert w.inObject()
  doAssert w.wantName

  w.wantName = false

  if w.empty:
    w.empty = false
  else:
    append ','

  indent()

  append '"'
  append name
  append '"'
  append ':'
  if w.hasPrettyOutput: append ' '

template writeMember*[T: void](w: var JsonWriter, name: string, body: T) =
  ## Write a member field of an object, ie the name followed by the value.
  ##
  ## Optional fields may be omitted depending on the Flavor.
  mixin writeValue

  w.writeName(name)
  w.writeElement:
    body

proc writeMember*[V: not void](
    w: var JsonWriter, name: string, value: V) {.raises: [IOError].} =
  ## Write a member field of an object, ie the name followed by the value.
  ##
  ## Optional fields may get omitted depending on the Flavor.
  mixin writeValue
  mixin flavorOmitsOptionalFields, shouldWriteObjectField

  type
    Writer = typeof w
    Flavor = Writer.Flavor

  when flavorOmitsOptionalFields(Flavor):
    if shouldWriteObjectField(value):
      w.writeName(name)
      w.writeElement(value)

  else:
    w.writeName(name)
    w.writeElement(value)

template beginObjectMember*(w: var JsonWriter, name: string) =
  w.writeName(name)
  w.beginObjectElement()

template beginObjectMember*(w: var JsonWriter, name: string, O: type) =
  w.writeName(name)
  w.beginObjectElement(O)

template endObjectMember*(w: var JsonWriter) =
  w.endObjectElement()

template beginArrayMember*(w: var JsonWriter, name: string) =
  w.writeName(name)
  w.beginArrayElement()

template endArrayMember*(w: var JsonWriter) =
  w.endArrayElement()

iterator stepwiseArrayCreation*[C](w: var JsonWriter, collection: C): auto {.raises: [IOError].} =
  ## Iterate over the members of a collection, expecting each member to be
  ## written directly to the stream (akin to using `writeValue` and not
  ## `writeElement`)
  w.beginArray()
  for e in collection:
    w.beginElement()
    yield e
    w.endElement()
  w.endArray()

proc writeIterable*(w: var JsonWriter, collection: auto) {.raises: [IOError].} =
  mixin writeValue
  w.beginArray()
  for e in collection:
    w.writeElement(e)
  w.endArray()

template writeArray*[T: void](w: var JsonWriter, body: T) =
  w.beginArray()
  body
  w.endArray()

template writeArrayElement*[T: void](w: var JsonWriter, body: T) =
  w.beginArrayElement()
  body
  w.beginArrayElement()

template writeArrayMember*[T: void](w: var JsonWriter, name: string, body: T) =
  w.beginArrayMember(name)
  body
  w.endArrayMember()

proc writeArray*[C: not void](w: var JsonWriter, values: C) {.raises: [IOError].} =
  w.writeIterable(values)

template writeObject*[T: void](w: var JsonWriter, O: type, body: T) =
  w.beginObject(O)
  body
  w.endObject()

template writeObject*[T: void](w: var JsonWriter, body: T) =
  w.beginObject()
  body
  w.endObject()

template writeObjectElement*[T: void](w: var JsonWriter, body: T) =
  w.beginObjectElement()
  body
  w.endObjectElement()

template writeObjectElement*[T: void](w: var JsonWriter, O: type, body: T) =
  w.beginObjectElement(O)
  body
  w.endObjectElement()

template writeObjectMember*[T: void](w: var JsonWriter, name: string, body: T) =
  w.beginObjectMember(name)
  body
  w.endObjectMember()

template writeObjectMember*[T: void](w: var JsonWriter, name: string, O: type, body: T) =
  w.beginObjectMember(name, O)
  body
  w.endObjectMember()

template writeObjectField*[FieldType, RecordType](w: var JsonWriter,
                                                  record: RecordType,
                                                  fieldName: static string,
                                                  field: FieldType) =
  mixin writeFieldIMPL, writeValue

  w.writeName(fieldName)

  w.beginElement()
  when RecordType is tuple:
    w.writeValue(field)
  else:
    type R = type record
    w.writeFieldIMPL(FieldTag[R, fieldName], field, record)
  w.endElement()

proc writeRecordValue*(w: var JsonWriter, value: object|tuple) {.raises: [IOError].} =
  mixin enumInstanceSerializedFields, writeObjectField
  mixin flavorOmitsOptionalFields, shouldWriteObjectField

  type RecordType = type value
  w.beginObject(RecordType)
  value.enumInstanceSerializedFields(fieldName, fieldValue):
    when fieldValue isnot JsonVoid:
      type
        Writer = typeof w
        Flavor = Writer.Flavor
      when flavorOmitsOptionalFields(Flavor):
        if shouldWriteObjectField(fieldValue):
          writeObjectField(w, value, fieldName, fieldValue)
      else:
        writeObjectField(w, value, fieldName, fieldValue)
    else:
      discard fieldName
  w.endObject()

proc writeValue*(w: var JsonWriter, value: JsonNumber) {.raises: [IOError].} =
  if value.sign == JsonSign.Neg:
    append '-'

  when value.integer is uint64:
    w.stream.writeText value.integer
  else:
    append value.integer

  if value.fraction.len > 0:
    append '.'
    append value.fraction

  template writeExp(body: untyped) =
    when value.exponent is uint64:
      if value.exponent > 0:
        body
    else:
      if value.exponent.len > 0:
        body

  writeExp:
    append 'e'
    if value.expSign == JsonSign.Neg:
      append '-'
    when value.exponent is uint64:
      w.stream.writeText value.exponent
    else:
      append value.exponent

proc writeValue*(w: var JsonWriter, value: JsonObjectType) {.raises: [IOError].} =
  w.beginObject()
  for name, v in value:
    w.writeMember(name, v)
  w.endObject()

proc writeValue*(w: var JsonWriter, value: JsonValue) {.raises: [IOError].} =
  case value.kind
  of JsonValueKind.String:
    w.writeValue(value.strVal)
  of JsonValueKind.Number:
    w.writeValue(value.numVal)
  of JsonValueKind.Object:
    w.writeValue(value.objVal)
  of JsonValueKind.Array:
    w.writeValue(value.arrayVal)
  of JsonValueKind.Bool:
    w.writeValue(value.boolVal)

  of JsonValueKind.Null:
    append "null"

template writeEnumImpl(w: var JsonWriter, value, enumRep) =
  mixin writeValue
  when enumRep == EnumAsString:
    w.writeValue $value
  elif enumRep == EnumAsNumber:
    w.writeValue value.int
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

# this construct catches `array[N, char]` which otherwise won't decompose into
# openArray[char] - we treat any array-like thing-of-characters as a string in
# the output
template isStringLike(v: string|cstring|openArray[char]|seq[char]): bool = true
template isStringLike[N](v: array[N, char]): bool = true
template isStringLike(v: auto): bool = false

proc writeValue*[V: not void](w: var JsonWriter, value: V) {.raises: [IOError].} =
  ## `writeValue` is a low-level operation for encoding `value` as JSON without
  ## adorning it with `beginElement`/`endElement`/`writeName`.
  ##
  ## When writing inside a nested object / array, prefer
  ## `writeMember` / `writeElement` respectively that will make the right
  ## adornments.
  mixin writeValue

  when value is JsonNode:
    append if w.hasPrettyOutput: value.pretty
           else: $value

  elif value is JsonString:
    append string(value)

  elif value is JsonVoid:
    discard

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
    {.error: "Failed to convert to JSON an unsupported type: " & typeName.}

proc toJson*(v: auto, pretty = false, typeAnnotations = false, Flavor = DefaultFlavor): string =
  mixin writeValue

  var
    s = memoryOutput()
    w = JsonWriter[Flavor].init(s, pretty, typeAnnotations)
  try:
    w.writeValue v
  except IOError:
    raiseAssert "no exceptions from memoryOutput"
  s.getOutput(string)

# nim-serialization integration / naming

template beginRecord*(w: var JsonWriter) = beginObject(w, false)
template beginRecord*(w: var JsonWriter, T: type) = beginObject(w, T, false)

template writeFieldName*(w: var JsonWriter, name: string) = writeName(w, name)

template writeField*(w: var JsonWriter, name: string, value: auto) =
  writeMember(w, name, value)

template endRecord*(w: var JsonWriter) = w.endObject(false)

template endRecordField*(w: var JsonWriter) {.deprecated: "endObject".} =
  endRecord(w)

template fieldWritten*(w: var JsonWriter) {.deprecated: "endElement".} =
  w.endElement()

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
