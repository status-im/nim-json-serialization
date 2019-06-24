import std/net, ../../json_serialization.nim
export net

proc writeValue*(writer: var JsonWriter, value: Port) =
  writeValue(writer, uint16 value)

proc readValue*(reader: var JsonReader, value: var Port) =
  value = Port reader.readValue(uint16)

