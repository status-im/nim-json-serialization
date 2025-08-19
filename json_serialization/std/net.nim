# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import ../../json_serialization, std/net
export net

proc writeValue*(writer: var JsonWriter, value: IpAddress) {.raises: [IOError].} =
  writeValue(writer, $value)

proc readValue*(
    reader: var JsonReader, value: var IpAddress
) {.raises: [IOError, SerializationError].} =
  let s = reader.readValue(string)
  try:
    value = parseIpAddress s
  except CatchableError:
    raiseUnexpectedValue(reader, "Invalid IP address")

proc writeValue*(writer: var JsonWriter, value: Port) {.raises: [IOError].} =
  writeValue(writer, uint16 value)

proc readValue*(
    reader: var JsonReader, value: var Port
) {.raises: [IOError, SerializationError].} =
  value = Port reader.readValue(uint16)
