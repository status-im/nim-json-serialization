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

proc writeValue*(writer: var JsonWriter, value: Option) {.raises: [IOError].} =
  mixin writeValue

  if value.isSome:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Option[T]) {.
      raises: [IOError, SerializationError].} =
  mixin readValue

  if reader.tokKind == JsonValueKind.Null:
    reset value
    reader.parseNull()
  else:
    value = some reader.readValue(T)
