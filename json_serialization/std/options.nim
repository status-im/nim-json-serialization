import std/options, ../../json_serialization/[reader, writer, lexer]
export options

template writeObjectField*(w: var JsonWriter,
                           record: auto,
                           fieldName: static string,
                           field: Option): bool =
  mixin writeObjectField

  if field.isSome:
    writeObjectField(w, record, fieldName, field.get)
  else:
    false

proc writeValue*(writer: var JsonWriter, value: Option) =
  mixin writeValue

  if value.isSome:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Option[T]) =
  mixin readValue

  let tok = reader.lexer.lazyTok
  if tok == tkNull:
    reset value
    reader.lexer.next()
  else:
    value = some reader.readValue(T)
