import
  stew/results, ../../json_serialization/[reader, writer, lexer]

export
  results

template writeField*[T](w: var JsonWriter,
                        record: auto,
                        fieldName: static string,
                        field: Result[T, void]) =
  if field.isOk:
    writeField(w, record, fieldName, field.get)

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
