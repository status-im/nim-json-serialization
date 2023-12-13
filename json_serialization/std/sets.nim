# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import stew/shims/sets, ../../json_serialization/[reader, writer, lexer]
export sets

type
  SetType = OrderedSet | HashSet | set

proc writeValue*(writer: var JsonWriter, value: SetType) {.raises: [IOError].} =
  writer.writeIterable value

proc readValue*(reader: var JsonReader, value: var SetType) =
  type ElemType = type(value.items)
  value = init SetType
  for elem in readArray(reader, ElemType):
    value.incl elem
