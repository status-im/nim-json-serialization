import
  std/[net, strutils],
  ../../json_serialization, chronos/transports/common

export
  net, common

proc writeValue*(writer: var JsonWriter, value: Port) =
  writeValue(writer, uint16 value)

proc readValue*(reader: var JsonReader, value: var Port) =
  value = Port reader.readValue(uint16)

proc writeValue*(writer: var JsonWriter, value: AddressFamily) =
  writeValue(writer, $value)

proc readValue*(reader: var JsonReader, value: var AddressFamily) =
  value = parseEnum[AddressFamily](reader.readValue(string))

