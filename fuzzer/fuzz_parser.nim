# json-serialization
# Copyright (c) 2023-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  testutils/fuzzing,
  faststreams,
  ../json_serialization/parser

func toReader(input: openArray[byte]): JsonReader[Json] =
  var stream = unsafeMemoryInput(input)
  JsonReader[Json].init(stream)

proc executeParser(payload: openArray[byte]) =
  try:
    var r = toReader(payload)
    let z = r.parseValue(uint64)
    discard z
  except JsonReaderError:
    discard

test:
  executeParser(payload)
