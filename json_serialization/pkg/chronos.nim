# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import chronos/transports/common, ../../json_serialization, ../std/net

export common, net

proc writeValue*(
    writer: var JsonWriter, value: TransportAddress
) {.raises: [IOError].} =
  writeValue(writer, $value)

proc readValue*(
    reader: var JsonReader, value: var TransportAddress
) {.raises: [IOError, SerializationError].} =
  value =
    try:
      initTAddress(reader.readValue(string))
    except TransportAddressError as exc:
      reader.raiseUnexpectedValue("Cannot parse TransportAddress: " & exc.msg)
