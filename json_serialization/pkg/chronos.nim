# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import ../../json_serialization/[reader, writer], ../std/net

from chronos/transports/common import
  TransportAddress, TransportAddressError, initTAddress, `$`

export TransportAddress, net

proc writeValue*(w: var JsonWriter, value: TransportAddress) {.raises: [IOError].} =
  w.writeValue($value)

proc readValue*(
    r: var JsonReader, value: var TransportAddress
) {.raises: [IOError, SerializationError].} =
  let s = r.readValue(string)
  try:
    value = initTAddress(s)
  except TransportAddressError as exc:
    r.raiseUnexpectedValue("Cannot parse TransportAddress: " & exc.msg)
