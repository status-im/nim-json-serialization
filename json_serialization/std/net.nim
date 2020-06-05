import
  std/strutils, stew/shims/net,
  ../../json_serialization, chronos/transports/common

export
  net, common

proc writeValue*(writer: var JsonWriter, value: IpAddress) =
  writeValue(writer, $value)

proc readValue*(reader: var JsonReader, value: var IpAddress) =
  let s = reader.readValue(string)
  try:
    value = parseIpAddress s
  except CatchableError:
    raiseUnexpectedValue(reader, "Invalid IP address")

template writeValue*(writer: var JsonWriter, value: ValidIpAddress) =
  writeValue writer, IpAddress(value)

template readValue*(reader: var JsonReader, value: var ValidIpAddress) =
  readValue reader, IpAddress(value)

proc writeValue*(writer: var JsonWriter, value: Port) =
  writeValue(writer, uint16 value)

proc readValue*(reader: var JsonReader, value: var Port) =
  value = Port reader.readValue(uint16)

proc writeValue*(writer: var JsonWriter, value: AddressFamily) =
  writeValue(writer, $value)

proc readValue*(reader: var JsonReader, value: var AddressFamily) =
  value = parseEnum[AddressFamily](reader.readValue(string))

