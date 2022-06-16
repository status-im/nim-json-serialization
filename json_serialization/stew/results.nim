import
  stew/results, ../../json_serialization/[reader, writer, lexer]

export
  results

template writeField*[T](w: var JsonWriter,
                        fieldName: static string,
                        field: Result[T, void],
                        record: auto) =
  if field.isOk:
    writeField(w, fieldName, field.get, record)

proc writeValue*[T](writer: var JsonWriter, value: Result[T, void]) =
  if value.isOk:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Result[T, void]) =
  let tok = reader.lexer.lazyTok
  if tok == tkNull:
    reset value
    reader.lexer.next()
  else:
    value.ok reader.readValue(T)
