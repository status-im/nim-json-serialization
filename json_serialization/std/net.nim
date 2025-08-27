# json_serialization
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

when compiles((; import chronos/transports/common)):
  # Backwards-compat with json_ser <= 0.4.2
  import ../pkg/chronos as jschronos
  export jschronos

proc writeValue*(w: var JsonWriter, value: IpAddress) {.raises: [IOError].} =
  w.writeValue($value)

proc readValue*(
    r: var JsonReader, value: var IpAddress
) {.raises: [IOError, SerializationError].} =
  let s = r.readValue(string)
  try:
    value = parseIpAddress(s)
  except ValueError as exc:
    r.raiseUnexpectedValue(exc.msg)

Port.serializesAsBase(Json)

{.pop.}
