# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import stew/shims/sets, ../../json_serialization/[reader, writer, lexer]
export sets

type SetType = OrderedSet | HashSet | set

proc writeValue*(w: var JsonWriter, value: SetType) {.raises: [IOError].} =
  w.writeIterable value

proc readValue*(
    r: var JsonReader, value: var SetType
) {.raises: [IOError, SerializationError].} =
  type ElemType = type(value.items)
  value = init SetType
  for elem in r.readArray(ElemType):
    value.incl elem
