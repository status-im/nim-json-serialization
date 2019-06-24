import std/options, ../../json_serialization/[reader, writer, lexer]
export options

proc writeValue*(writer: var JsonWriter, value: Option) =
  if value.isSome:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Option[T]) =
  let tok = reader.lexer.tok
  if tok == tkNull:
    reset value
    reader.lexer.next()
  else:
    value = some reader.readValue(T)

