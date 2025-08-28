# json_serialization
# Copyright (c) 2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import ../../json_serialization, std/uri
export uri

proc writeValue*(w: var JsonWriter, value: Uri) {.raises: [IOError].} =
  w.writeValue($value)

proc readValue*(
    r: var JsonReader, value: var Uri
) {.raises: [IOError, SerializationError].} =
  let s = r.readValue(string)
  try:
    value = parseUri(s)
  except ValueError as exc:
    r.raiseUnexpectedValue(exc.msg)

{.pop.}
