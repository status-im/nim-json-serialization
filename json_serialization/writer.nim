# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

## The `writer` module contains utilities for implementing custom JSON output,
## both when implementing `writeValue` to provide custom serialization of a type
## and when streaming JSON directly without first creating Nim objects.
##
## The API closely follows the [JSON grammar](https://www.json.org/).
##
## JSON values are generally written using `writeValue`. It is also possible to
## stream the members and elements of objects/arrays using the
## `writeArray`/`writeObject` templates - alternatively, the low-level
## `begin{Array,Object}` and `end{Array,Object}` helpers provide fine-grained
## writing access.
##
## Finally, `streamElement` can be used when direct access to the stream is
## needed, for example to efficiently encode a value without intermediate
## allocations.

{.push raises: [], gcsafe.}

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
    stream: OutputStream
    hasTypeAnnotations: bool
    hasPrettyOutput*: bool # read-only
    stack: seq[CollectionKind]
      # Stack that keeps track of nested arrays/objects
    empty: bool
      # True before any members / elements have been written to an object / array
    wantName: bool
      # The next output should be a name (for an object member)

Json.setWriter JsonWriter,
               PreferredOutput = string

template nestingLevel(w: JsonWriter): int =
  w.stack.len * 2

func init*(W: type JsonWriter, stream: OutputStream,
           pretty = false, typeAnnotations = false): W =
  ## Initialize a new JsonWriter with the given output stream.
  ## Optionally enables pretty output and type annotations.
  ##
  ## The writer generally does not need closing or flushing, which instead is
  ## managed by the stream itself.
  W(stream: stream,
    hasPrettyOutput: pretty,
    hasTypeAnnotations: typeAnnotations)

proc writeValue*[V: not void](w: var JsonWriter, value: V) {.raises: [IOError].}
  ## Write value as JSON - this is the main entry point for converting "anything"
  ## to JSON.
  ##
  ## See also `writeMember`.

proc writeMember*[V: not void](w: var JsonWriter, name: string, value: V) {.raises: [IOError].}
  ## Write `name` and `value` as a JSON member / field of an object.

template shouldWriteObjectField*[FieldType](field: FieldType): bool = true
  ## Template to determine if an object field should be written.
  ## Called when `omitsOptionalField` is enabled - the field is omitted if the
  ## template returns `false`.

template indent =
  if w.hasPrettyOutput:
    w.stream.write "\n"
    for i in 0 ..< w.nestingLevel:
      w.stream.write ' '

func inArray(w: JsonWriter): bool =
  w.stack.len > 0 and w.stack[^1] == Array

func inObject(w: JsonWriter): bool =
  w.stack.len > 0 and w.stack[^1] == Object

proc beginElement(w: var JsonWriter) {.raises: [IOError].} =
  ## Start writing an array element or the value part of an object member.
  ##
  ## Must be closed with a corresponding `endElement`.
  ##
  ## The framework takes care to call `beginElement`/`endElement` as necessary
  ## as part of `writeValue` and `streamElement`.
  doAssert not w.wantName

  if w.inArray:
    if w.empty:
      w.empty = false
    else:
      w.stream.write ','

    indent()

proc endElement(w: var JsonWriter) =
  ## Matching `end` call for `beginElement`
  w.wantName = w.inObject

proc beginObject*(w: var JsonWriter) {.raises: [IOError].} =
  ## Start writing an object, to be followed by member fields.
  ##
  ## Must be closed with a matching `endObject`.
  ##
  ## See also `writeObject`.
  ##
  ## Use `writeMember` to add member fields to the object.
  w.beginElement()

  w.stream.write '{'

  w.empty = true
  w.wantName = true

  w.stack.add(Object)

proc beginObject*(w: var JsonWriter, O: type) {.raises: [IOError].} =
  ## Start writing an object with type annotation, to be followed by member fields.
  ##
  ## Must be closed with a matching `endObject`.
  w.beginObject()
  if w.hasTypeAnnotations: w.writeMember("$type", typetraits.name(O))

proc endObject*(w: var JsonWriter) {.raises: [IOError].} =
  ## Finish writing an object started with `beginObject`.
  doAssert w.stack.pop() == Object

  if not w.empty:
    indent()

  w.empty = false
  w.stream.write '}'

  w.endElement()

proc beginArray*(w: var JsonWriter) {.raises: [IOError].} =
  ## Start writing a JSON array.
  ## Must be closed with a matching `endArray`.
  w.beginElement()

  w.stream.write '['

  w.empty = true

  w.stack.add(Array)

proc endArray*(w: var JsonWriter) {.raises: [IOError].} =
  ## Finish writing a JSON array started with `beginArray`.
  doAssert w.stack.pop() == Array

  if not w.empty:
    indent()

  w.empty = false

  w.stream.write ']'

  w.endElement()

template streamElement*(w: var JsonWriter, streamVar: untyped, body: untyped) =
  ## Write an element giving direct access to the underlying stream - each
  ## separate JSON value needs to be written in its own `streamElement` block.
  ##
  ## Within the `streamElement` block, do not use `writeValue` and other
  ## high-level helpers as these already perform the element tracking done in
  ## `streamElement`.
  w.beginElement()
  let streamVar = w.stream
  body
  w.endElement()

proc writeName*(w: var JsonWriter, name: string) {.raises: [IOError].} =
  ## Write the name part of the member of an object, to be followed by the value.
  doAssert w.inObject()
  doAssert w.wantName

  w.wantName = false

  if w.empty:
    w.empty = false
  else:
    w.stream.write ','

  indent()

  w.stream.write '"'
  w.stream.write name
  w.stream.write '"'
  w.stream.write ':'
  if w.hasPrettyOutput: w.stream.write ' '

template writeMember*[T: void](w: var JsonWriter, name: string, body: T) =
  ## Write a member field of an object, i.e., the name followed by the value.
  ##
  ## Optional field handling is not performed and must be done manually.
  w.writeName(name)
  body

proc writeMember*[V: not void](
    w: var JsonWriter, name: string, value: V) {.raises: [IOError].} =
  ## Write a member field of an object, i.e., the name followed by the value.
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
      w.writeValue(value)

  else:
    w.writeName(name)
    w.writeValue(value)

iterator stepwiseArrayCreation*[C](w: var JsonWriter, collection: C): auto {.raises: [IOError].} =
  ## Iterate over the members of a collection, expecting each member to be
  ## written directly to the stream.
  w.beginArray()
  for e in collection:
    yield e
  w.endArray()

proc writeIterable*(w: var JsonWriter, collection: auto) {.raises: [IOError].} =
  ## Write each element of a collection as a JSON array.
  mixin writeValue
  w.beginArray()
  for e in collection:
    w.writeValue(e)
  w.endArray()

template writeArray*[T: void](w: var JsonWriter, body: T) =
  ## Write a JSON array using a code block for its elements.
  w.beginArray()
  body
  w.endArray()

proc writeArray*[C: not void](w: var JsonWriter, values: C) {.raises: [IOError].} =
  ## Write a collection as a JSON array.
  w.writeIterable(values)

template writeObject*[T: void](w: var JsonWriter, O: type, body: T) =
  ## Write a JSON object with type annotation using a code block for its fields.
  w.beginObject(O)
  body
  w.endObject()

template writeObject*[T: void](w: var JsonWriter, body: T) =
  ## Write a JSON object using a code block for its fields.
  w.beginObject()
  body
  w.endObject()

template writeObjectField*[FieldType, RecordType](w: var JsonWriter,
                                                  record: RecordType,
                                                  fieldName: static string,
                                                  field: FieldType) =
  ## Write a field of a record or tuple as a JSON object member.
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
  ## Write a record or tuple as a JSON object.
  ##
  ## This function exists to satisfy the nim-serialization API - use `writeValue`
  ## to serialize objects when using `Jsonwriter`.
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
  w.streamElement(s):
    if value.sign == JsonSign.Neg:
      s.write '-'

    when value.integer is uint64:
      w.stream.writeText value.integer
    else:
      s.write value.integer

    if value.fraction.len > 0:
      s.write '.'
      s.write value.fraction

    template writeExp(body: untyped) =
      when value.exponent is uint64:
        if value.exponent > 0:
          body
      else:
        if value.exponent.len > 0:
          body

    writeExp:
      s.write 'e'
      if value.expSign == JsonSign.Neg:
        s.write '-'
      when value.exponent is uint64:
        w.stream.writeText value.exponent
      else:
        s.write value.exponent

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
    w.streamElement(s):
      s.write "null"

template writeEnumImpl(w: var JsonWriter, value, enumRep) =
  mixin writeValue
  when enumRep == EnumAsString:
    w.writeValue $value
  elif enumRep == EnumAsNumber:
    w.writeValue value.int
  elif enumRep == EnumAsStringifiedNumber:
    w.writeValue $value.int

template writeValue*(w: var JsonWriter, value: enum) =
  ## Write an enum value as JSON according to the flavor's enum representation.
  type Flavor = type(w).Flavor
  writeEnumImpl(w, value, Flavor.flavorEnumRep())

type
  StringLikeTypes = string|cstring|openArray[char]|seq[char]

template isStringLike(v: StringLikeTypes): bool = true
template isStringLike[N](v: array[N, char]): bool = true
template isStringLike(v: auto): bool = false

template autoSerializeCheck(F: distinct type, T: distinct type) =
  when declared(macrocache.hasKey): # Nim 1.6 have no macrocache.hasKey
    mixin typeAutoSerialize
    when not F.typeAutoSerialize(T):
      const typeName = typetraits.name(T)
      {.error: "automatic serialization is not enabled or writeValue not implemented for `" &
        typeName & "`".}

template autoSerializeCheck(F: distinct type, TC: distinct type, M: distinct type) =
  when declared(macrocache.hasKey): # Nim 1.6 have no macrocache.hasKey
    mixin typeClassOrMemberAutoSerialize
    when not F.typeClassOrMemberAutoSerialize(TC, M):
      const typeName = typetraits.name(M)
      const typeClassName = typetraits.name(TC)
      {.error: "automatic serialization is not enabled or writeValue not implemented for `" &
        typeName & "` of typeclass `" & typeClassName & "`".}

proc writeValue*[V: not void](w: var JsonWriter, value: V) {.raises: [IOError].} =
  ## Write a generic value as JSON, using type-based dispatch. Overload this
  ## function to provide custom conversions of your own types.
  mixin writeValue

  type Flavor = JsonWriter.Flavor

  when value is JsonNode:
    autoSerializeCheck(Flavor, JsonNode)
    w.streamElement(s):
      s.write if w.hasPrettyOutput: value.pretty
              else: $value

  elif value is JsonString:
    autoSerializeCheck(Flavor, JsonString)
    w.streamElement(s):
      s.write $value

  elif value is JsonVoid:
    autoSerializeCheck(Flavor, JsonVoid)
    discard

  elif value is ref:
    autoSerializeCheck(Flavor, ref, typeof(value))
    if value.isNil:
      w.streamElement(s):
        s.write "null"
    else:
      writeValue(w, value[])

  elif isStringLike(value):
    when value isnot array:
      autoSerializeCheck(Flavor, StringLikeTypes, typeof(value))
    when value is array:
      autoSerializeCheck(Flavor, array, typeof(value))
    w.streamElement(s):
      when value is cstring:
        if value == nil:
          s.write "null"
          return

      s.write '"'

      template addPrefixSlash(c) =
        s.write '\\'
        s.write c
      const hexChars = "0123456789abcde"
      for c in value:
        case c
        of '\b': addPrefixSlash 'b' # \x08
        of '\t': addPrefixSlash 't' # \x09
        of '\n': addPrefixSlash 'n' # \x0a
        of '\f': addPrefixSlash 'f' # \x0c
        of '\r': addPrefixSlash 'r' # \x0d
        of '"' : addPrefixSlash '\"'
        of '\x00'..'\x07', '\x0b', '\x0e'..'\x1f':
          s.write "\\u00"
          s.write hexChars[(uint8(c) shr 4) and 0x0f]
          s.write hexChars[uint8(c) and 0x0f]

        else: s.write c

      s.write '"'

  elif value is bool:
    autoSerializeCheck(Flavor, bool)
    w.streamElement(s):
      s.write if value: "true" else: "false"

  elif value is range:
    autoSerializeCheck(Flavor, range, typeof(value))
    when low(typeof(value)) < 0:
      w.writeValue int64(value)
    else:
      w.writeValue uint64(value)

  elif value is SomeInteger:
    autoSerializeCheck(Flavor, SomeInteger, typeof(value))
    w.streamElement(s):
      s.writeText value

  elif value is SomeFloat:
    autoSerializeCheck(Flavor, SomeFloat, typeof(value))
    w.streamElement(s):
      # TODO Implement writeText for floats
      #      to avoid the allocation here:
      s.write $value

  elif value is (seq or array or openArray) or
      (value is distinct and distinctBase(value) is (seq or array or openArray)):

    when value is seq or(value is distinct and distinctBase(value) is seq):
      autoSerializeCheck(Flavor, seq, typeof(value))
    when value is array or(value is distinct and distinctBase(value) is array):
      autoSerializeCheck(Flavor, array, typeof(value))
    when value is openArray or(value is distinct and distinctBase(value) is openArray):
      autoSerializeCheck(Flavor, openArray, typeof(value))
    when value is distinct:
      w.writeArray(distinctBase value)
    else:
      w.writeArray(value)

  elif value is (distinct or object or tuple):
    when value is object:
      autoSerializeCheck(Flavor, object, typeof(value))
    when value is tuple:
      autoSerializeCheck(Flavor, tuple, typeof(value))
    when value is distinct:
      autoSerializeCheck(Flavor, distinct, typeof(value))
    mixin flavorUsesAutomaticObjectSerialization

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
  ## Convert a value to its JSON string representation.
  ## Optionally enables pretty output and type annotations.
  mixin writeValue

  var
    s = memoryOutput()
    w = JsonWriter[DefaultFlavor].init(s, pretty, typeAnnotations)
  try:
    w.writeValue v
  except IOError:
    raiseAssert "memoryOutput is exception-free"
  s.getOutput(string)

# nim-serialization integration / naming

template beginRecord*(w: var JsonWriter) = beginObject(w)
  ## Alias for beginObject, for record serialization.

template beginRecord*(w: var JsonWriter, T: type) = beginObject(w, T)
  ## Alias for beginObject with type, for record serialization.

template writeFieldName*(w: var JsonWriter, name: string) = writeName(w, name)
  ## Alias for writeName, for record serialization.

template writeField*(w: var JsonWriter, name: string, value: auto) =
  ## Alias for writeMember, for record serialization.
  writeMember(w, name, value)

template endRecord*(w: var JsonWriter) = w.endObject()
  ## Alias for endObject, for record serialization.

template serializesAsTextInJson*(T: type[enum]) =
  ## Configure an enum type to serialize as text in JSON.
  template writeValue*(w: var JsonWriter, val: T) =
    w.writeValue $val

template configureJsonSerialization*(
    T: type[enum], enumRep: static[EnumRepresentation]) =
  ## Configure JSON serialization for an enum type with a specific representation.
  proc writeValue*(w: var JsonWriter,
                   value: T) {.raises: [IOError].} =
    writeEnumImpl(w, value, enumRep)

template configureJsonSerialization*(Flavor: type,
                        T: type[enum],
                        enumRep: static[EnumRepresentation]) =
  ## Configure JSON serialization for an enum type and flavor with a specific representation.
  when Flavor is Json:
    proc writeValue*(w: var JsonWriter[DefaultFlavor],
                     value: T) {.raises: [IOError].} =
      writeEnumImpl(w, value, enumRep)
  else:
    proc writeValue*(w: var JsonWriter[Flavor],
                     value: T) {.raises: [IOError].} =
      writeEnumImpl(w, value, enumRep)
