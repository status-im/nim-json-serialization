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

proc writeValue*(w: var JsonWriter, value: IpAddress) {.raises: [IOError].} =
  writeValue(w, $value)

proc readValue*(
    r: var JsonReader, value: var IpAddress
) {.raises: [IOError, SerializationError].} =
  let s = r.readValue(string)
  try:
    value = parseIpAddress s
  except CatchableError:
    raiseUnexpectedValue(r, "Invalid IP address")

proc writeValue*(w: var JsonWriter, value: Port) {.raises: [IOError].} =
  writeValue(w, uint16 value)

proc readValue*(
    r: var JsonReader, value: var Port
) {.raises: [IOError, SerializationError].} =
  value = Port r.readValue(uint16)
