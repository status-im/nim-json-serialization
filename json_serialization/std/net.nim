# json-serialization
# Copyright (c) 2019-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[net, strutils],
  chronos/transports/common,
  ../../json_serialization

export
  net, common

proc writeValue*(
    writer: var JsonWriter, value: IpAddress) {.raises: [IOError].} =
  writeValue(writer, $value)

proc readValue*(reader: var JsonReader, value: var IpAddress) =
  let s = reader.readValue(string)
  try:
    value = parseIpAddress s
  except CatchableError:
    raiseUnexpectedValue(reader, "Invalid IP address")

proc writeValue*(
    writer: var JsonWriter, value: Port) {.raises: [IOError].} =
  writeValue(writer, uint16 value)

proc readValue*(reader: var JsonReader, value: var Port) =
  value = Port reader.readValue(uint16)

proc writeValue*(
    writer: var JsonWriter, value: AddressFamily) {.raises: [IOError].} =
  writeValue(writer, $value)

proc readValue*(reader: var JsonReader, value: var AddressFamily) =
  value = parseEnum[AddressFamily](reader.readValue(string))
