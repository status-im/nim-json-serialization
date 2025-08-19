# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import std/options, ../../json_serialization/[reader, writer, lexer]
export options

template shouldWriteObjectField*(field: Option): bool =
  field.isSome

proc writeValue*(w: var JsonWriter, value: Option) {.raises: [IOError].} =
  mixin writeValue

  if value.isSome:
    w.writeValue value.get
  else:
    w.writeValue JsonString("null")

proc readValue*[T](
    r: var JsonReader, value: var Option[T]
) {.raises: [IOError, SerializationError].} =
  mixin readValue

  if r.tokKind == JsonValueKind.Null:
    reset value
    r.parseNull()
  else:
    value = some r.readValue(T)
