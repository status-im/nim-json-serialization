import stew/shims/sets, ../../json_serialization/[reader, writer, lexer]
export sets

type
  SetType = OrderedSet | HashSet | set

proc writeValue*(writer: var JsonWriter, value: SetType) =
  writer.writeIterable value

proc readValue*(reader: var JsonReader, value: var SetType) =
  type ElemType = type(value.items)
  value = init SetType
  for elem in readArray(reader, ElemType):
    value.incl elem

