# json-serialization
# Copyright (c) 2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2,
  ../json_serialization

func jsonBool(x: bool): JsonValueRef[uint64] =
  JsonValueRef[uint64](kind: JsonValueKind.Bool, boolVal: x)

suite "Test JsonValueRef":
  test "Test table keys equality":
    let a = JsonValueRef[uint64](
      kind: JsonValueKind.Object,
      objVal: [
        ("a", jsonBool(true)),
      ].toOrderedTable
    )

    let a2 = JsonValueRef[uint64](
      kind: JsonValueKind.Object,
      objVal: [
        ("a", jsonBool(true)),
      ].toOrderedTable
    )

    let b = JsonValueRef[uint64](
      kind: JsonValueKind.Object,
      objVal: [
        ("a", jsonBool(true)),
        ("b", jsonBool(true))
      ].toOrderedTable
    )

    check a != b
    check a == a2

