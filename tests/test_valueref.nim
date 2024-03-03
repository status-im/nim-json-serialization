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
  ../json_serialization,
  ../json_serialization/value_ops

func jsonBool(x: bool): JsonValueRef[uint64] =
  JsonValueRef[uint64](kind: JsonValueKind.Bool, boolVal: x)

func jsonNull(): JsonValueRef[uint64] =
  JsonValueRef[uint64](kind: JsonValueKind.Null)

suite "Test JsonValueRef":
  let objA = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("a", jsonBool(true)),
    ].toOrderedTable
  )

  let objA2 = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("a", jsonBool(true)),
    ].toOrderedTable
  )

  let objABNull = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("a", jsonBool(true)),
      ("b", jsonNull())
    ].toOrderedTable
  )

  let objAB = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("a", jsonBool(true)),
      ("b", jsonBool(true))
    ].toOrderedTable
  )

  let objInArrayA = JsonValueRef[uint64](
    kind: JsonValueKind.Array,
    arrayVal: @[
      objA
    ]
  )

  let objInArrayA2 = JsonValueRef[uint64](
    kind: JsonValueKind.Array,
    arrayVal: @[
      objA2
    ]
  )

  let objInArrayAB = JsonValueRef[uint64](
    kind: JsonValueKind.Array,
    arrayVal: @[
      objAB
    ]
  )

  let objInArrayABNull = JsonValueRef[uint64](
    kind: JsonValueKind.Array,
    arrayVal: @[
      objABNull
    ]
  )

  let objInObjA = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("x", objA)
    ].toOrderedTable
  )

  let objInObjA2 = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("x", objA2)
    ].toOrderedTable
  )

  let objInObjAB = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("x", objAB)
    ].toOrderedTable
  )

  let objInObjABNull = JsonValueRef[uint64](
    kind: JsonValueKind.Object,
    objVal: [
      ("x", objABNull)
    ].toOrderedTable
  )

  test "Test table keys equality":
    check objA != objAB
    check objA == objA2
    check objA != objABNull
    check objAB != objABNull

    check objInArrayA != objInArrayAB
    check objInArrayA != objInArrayABNull
    check objInArrayA == objInArrayA2
    check objInArrayAB != objInArrayABNull

    check objInObjA != objInObjAB
    check objInObjA != objInObjABNull
    check objInObjA == objInObjA2
    check objInObjAB != objInObjABNull

  test "Test compare":
    check compare(objA, objAB) == false
    check compare(objA, objA2) == true
    check compare(objA, objABNull) == true
    check compare(objAB, objABNull) == false

    check compare(objInArrayA, objInArrayAB) == false
    check compare(objInArrayA, objInArrayABNull) == true
    check compare(objInArrayA, objInArrayA2) == true
    check compare(objInArrayAB, objInArrayABNull) == false

    check compare(objInObjA, objInObjAB) == false
    check compare(objInObjA, objInObjABNull) == true
    check compare(objInObjA, objInObjA2) == true
    check compare(objInObjAB, objInObjABNull) == false
