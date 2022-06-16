import std/options, ../../json_serialization/[reader, writer, lexer]
export options

template writeField*(w: var JsonWriter,
                     fieldName: static string,
                     field: Option,
                     record: auto) =
  if field.isSome:
    writeField(w, fieldName, field.get, record)

proc writeValue*(writer: var JsonWriter, value: Option) =
  if value.isSome:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Option[T]) =
  let tok = reader.lexer.lazyTok
  if tok == tkNull:
    reset value
    reader.lexer.next()
  else:
    value = some reader.readValue(T)
