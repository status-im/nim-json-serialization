# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import pkg/results, ../../json_serialization/[reader, writer, lexer]

export results

template shouldWriteObjectField*[T](field: Opt[T]): bool =
  field.isOk

proc writeValue*[T](w: var JsonWriter, value: Opt[T]) {.raises: [IOError].} =
  mixin writeValue

  if value.isOk:
    w.writeValue(value.get)
  else:
    w.writeValue JsonString("null")

proc readValue*[T](
    r: var JsonReader, value: var Opt[T]
) {.raises: [IOError, SerializationError].} =
  mixin readValue

  if r.tokKind == JsonValueKind.Null:
    reset value
    r.parseNull()
  else:
    value.ok r.readValue(T)

func isFieldExpected*[T](_: type[Opt[T]]): bool {.compileTime.} =
  false
