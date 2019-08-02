import stew/shims/tables, ../../json_serialization/[reader, writer, lexer]
export tables

type
  TableType = OrderedTable | Table | TableRef

proc writeValue*(writer: var JsonWriter, value: TableType) =
  writer.beginRecord()
  for key, val in value:
    writer.writeField key, val
  writer.endRecord()

proc readValue*(reader: var JsonReader, value: var TableType) =
  type KeyType = type(value.keys)
  type ValueType = type(value.values)
  value = init TableType
  for (key, val) in readObject(reader, KeyType, ValueType):
    value[key] = val


