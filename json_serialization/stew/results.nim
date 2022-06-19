import
  stew/results, ../../json_serialization/[reader, writer, lexer]

export
  results

template writeObjectField*[T](w: var JsonWriter,
                              record: auto,
                              fieldName: static string,
                              field: Result[T, void]) =
  mixin writeObjectField

  if field.isOk:
    writeObjectField(w, record, fieldName, field.get)

proc writeValue*[T](writer: var JsonWriter, value: Result[T, void]) =
  mixin writeValue

  if value.isOk:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Result[T, void]) =
  mixin readValue

  let tok = reader.lexer.lazyTok
  if tok == tkNull:
    reset value
    reader.lexer.next()
  else:
    value.ok reader.readValue(T)
