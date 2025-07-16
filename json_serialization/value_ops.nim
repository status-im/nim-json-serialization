# json-serialization
# Copyright (c) 2023-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

import
  std/[tables, strutils],
  ./types

proc len*(n: JsonValueRef): int =
  ## If `n` is a `JsonValueKind.Array`, it returns the number of elements.
  ## If `n` is a `JsonValueKind.Object`, it returns the number of pairs.
  ## Else it returns 0.
  case n.kind
  of JsonValueKind.Array: result = n.arrayVal.len
  of JsonValueKind.Object: result = n.objVal.len
  else: discard

proc `[]`*(node: JsonValueRef, name: string): JsonValueRef {.inline.} =
  ## Gets a field from a `JsonValueKind.Object`, which must not be nil.
  assert(not isNil(node))
  assert(node.kind == JsonValueKind.Object)
  node.objVal.getOrDefault(name, nil)

proc `[]`*(node: JsonValueRef, index: int): JsonValueRef {.inline.} =
  ## Gets the node at `index` in an Array. Result is undefined if `index`
  ## is out of bounds, but as long as array bound checks are enabled it will
  ## result in an exception.
  assert(not isNil(node))
  assert(node.kind == JsonValueKind.Array)
  node.arrayVal[index]

proc contains*(node: JsonValueRef, key: string): bool =
  ## Checks if `key` exists in `node`.
  assert(node.kind == JsonValueKind.Object)
  node.objVal.hasKey(key)

proc contains*(node: JsonValueRef, val: JsonValueRef): bool =
  ## Checks if `val` exists in array `node`.
  assert(node.kind == JsonValueKind.Array)
  find(node.arrayVal, val) >= 0

proc `[]=`*(obj: JsonValueRef, key: string, val: JsonValueRef) {.inline.} =
  ## Sets a field from a `JsonValueKind.Object`.
  assert(obj.kind == JsonValueKind.Object)
  obj.objVal[key] = val

proc `[]=`*(obj: JsonValueRef, index: int, val: JsonValueRef) {.inline.} =
  ## Sets a field from a `JsonValueKind.Array`.
  assert(obj.kind == JsonValueKind.Array)
  obj.arrayVal[index] = val

proc `{}`*(node: JsonValueRef, keys: varargs[string]): JsonValueRef =
  ## Traverses the node and gets the given value. If any of the
  ## keys do not exist, returns ``nil``. Also returns ``nil`` if one of the
  ## intermediate data structures is not an object.
  result = node
  for key in keys:
    if isNil(result) or result.kind != JsonValueKind.Object:
      return nil
    result = result.objVal.getOrDefault(key)

proc getOrDefault*(node: JsonValueRef, key: string): JsonValueRef =
  ## Gets a field from a `node`. If `node` is nil or not an object or
  ## value at `key` does not exist, returns nil
  if not isNil(node) and node.kind == JsonValueKind.Object:
    result = node.objVal.getOrDefault(key)

proc delete*(obj: JsonValueRef, key: string) =
  ## Deletes ``obj[key]``.
  assert(obj.kind == JsonValueKind.Object)
  if not obj.objVal.hasKey(key):
    raise newException(IndexDefect, "key not in object")
  obj.objVal.del(key)

func compare*(lhs, rhs: JsonValueRef): bool

func compareObject(lhs, rhs: JsonValueRef): bool =
  ## assume lhs.len >= rhs.len
  ## null field and no field are treated equals
  for k, v in lhs.objVal:
    let rhsVal = rhs.objVal.getOrDefault(k, nil)
    if rhsVal.isNil:
      if v.kind != JsonValueKind.Null:
        return false
      else:
        continue
    if not compare(rhsVal, v):
      return false
  true

func compare*(lhs, rhs: JsonValueRef): bool =
  ## The difference between `==` and `compare`
  ## lies in the object comparison. Null field `compare`
  ## to non existent field will return true.
  ## On the other hand, `==` will return false.

  if lhs.isNil and rhs.isNil:
    return true

  if not lhs.isNil and rhs.isNil:
    return false

  if lhs.isNil and not rhs.isNil:
    return false

  if lhs.kind != rhs.kind:
    return false

  case lhs.kind
  of JsonValueKind.String:
    lhs.strVal == rhs.strVal
  of JsonValueKind.Number:
    lhs.numVal == rhs.numVal
  of JsonValueKind.Object:
    if lhs.objVal.len >= rhs.objVal.len:
      compareObject(lhs, rhs)
    else:
      compareObject(rhs, lhs)
  of JsonValueKind.Array:
    if lhs.arrayVal.len != rhs.arrayVal.len:
      return false
    for i, x in lhs.arrayVal:
      if not compare(x, rhs.arrayVal[i]):
        return false
    true
  of JsonValueKind.Bool:
    lhs.boolVal == rhs.boolVal
  of JsonValueKind.Null:
    true

{.pop.}
