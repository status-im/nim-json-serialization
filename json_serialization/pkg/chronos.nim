# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import chronos/transports/common, ../../json_serialization/[reader, writer], ../std/net

export common, net

proc writeValue*(w: var JsonWriter, value: TransportAddress) {.raises: [IOError].} =
  w.writeValue($value)

proc readValue*(
    r: var JsonReader, value: var TransportAddress
) {.raises: [IOError, SerializationError].} =
  value =
    try:
      initTAddress(r.readValue(string))
    except TransportAddressError as exc:
      r.raiseUnexpectedValue("Cannot parse TransportAddress: " & exc.msg)
