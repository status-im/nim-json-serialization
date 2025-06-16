# json-serialization
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  pkg/results, ../../json_serialization/[reader, writer, lexer]

export
  results

template shouldWriteObjectField*[T](field: Result[T, void]): bool =
  field.isOk

proc writeValue*[T](
    writer: var JsonWriter, value: Result[T, void]) {.raises: [IOError].} =
  mixin writeValue

  if value.isOk:
    writer.writeValue value.get
  else:
    writer.writeValue JsonString("null")

proc readValue*[T](reader: var JsonReader, value: var Result[T, void]) =
  mixin readValue

  if reader.tokKind == JsonValueKind.Null:
    reset value
    reader.parseNull()
  else:
    value.ok reader.readValue(T)

func isFieldExpected*[T, E](_: type[Result[T, E]]): bool {.compileTime.} =
  false
