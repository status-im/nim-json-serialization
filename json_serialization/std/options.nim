# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import std/options, ../../json_serialization/[reader, writer, lexer]
export options

template writeObjectField*(w: var JsonWriter,
                           record: auto,
                           fieldName: static string,
                           field: Option): bool =
  mixin writeObjectField

  if field.isSome:
    writeObjectField(w, record, fieldName, field.get)
  else:
    false

proc writeValue*(writer: var JsonWriter, value: Option) {.raises: [IOError].} =
  mixin writeValue, flavorOmitsOptionalFields
  type Flavor = JsonWriter.Flavor

  if value.isSome:
    writer.writeValue value.get
  elif not flavorOmitsOptionalFields(Flavor):
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Option[T]) =
  mixin readValue

  let tok = reader.lexer.lazyTok
  if tok == tkNull:
    reset value
    reader.lexer.next()
  else:
    value = some reader.readValue(T)
