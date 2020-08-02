import stew/shims/tables, ../../json_serialization/[reader, writer, lexer]
export tables

type
  TableType = OrderedTable | Table

proc writeValue*(writer: var JsonWriter, value: TableType) =
  writer.beginRecord()
  for key, val in value:
    writer.writeField $key, val
  writer.endRecord()

template to*(a: string, b: typed): untyped =
  {.error: "doesnt support keys with type " & $type(b) .}

template to*(a: string, b: type int): int =
  parseInt(a)

template to*(a: string, b: type float): float =
  parseFloat(a)

template to*(a: string, b: type string): string =
  a

proc readValue*(reader: var JsonReader, value: var TableType) =
  type KeyType = type(value.keys)
  type ValueType = type(value.values)
  value = init TableType
  for key, val in readObject(reader, string, ValueType):
    value[to(key, KeyType)] = val

