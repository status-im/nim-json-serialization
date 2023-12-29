# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/tables,
  serialization/errors

export
  tables,
  errors

type
  JsonError* = object of SerializationError

  # This is a special type to parse whatever
  # json value into string.
  JsonString* = distinct string

  # This is a special type to parse whatever
  # json value into nothing/skip it.
  JsonVoid* = object

  JsonSign* {.pure.} = enum
    None
    Pos
    Neg

  # This is a special type to parse complete
  # json number.
  JsonNumber*[T: string or uint64] = object
    sign*: JsonSign
    integer*: T
    fraction*: string
    expSign*: JsonSign
    exponent*: T

  JsonReaderFlag* {.pure.} = enum
    allowUnknownFields
    requireAllFields
    escapeHex
    relaxedEscape
    portableInt
    trailingComma       # on
    allowComments       # on
    leadingFraction     # on
    integerPositiveSign # on

  JsonReaderFlags* = set[JsonReaderFlag]

  JsonReaderConf* = object
    nestedDepthLimit*: int
    arrayElementsLimit*: int
    objectMembersLimit*: int
    integerDigitsLimit*: int
    fractionDigitsLimit*: int
    exponentDigitsLimit*: int
    stringLengthLimit*: int

  JsonValueKind* {.pure.} = enum
    String,
    Number,
    Object,
    Array,
    Bool,
    Null

  JsonObjectType*[T: string or uint64] = OrderedTable[string, JsonValueRef[T]]

  JsonValueRef*[T: string or uint64] = ref JsonValue[T]
  JsonValue*[T: string or uint64] = object
    case kind*: JsonValueKind
    of JsonValueKind.String:
      strVal*: string
    of JsonValueKind.Number:
      numVal*: JsonNumber[T]
    of JsonValueKind.Object:
      objVal*: JsonObjectType[T]
    of JsonValueKind.Array:
      arrayVal*: seq[JsonValueRef[T]]
    of JsonValueKind.Bool:
      boolVal*: bool
    of JsonValueKind.Null:
      discard


const
  minPortableInt* = -9007199254740991 # -2**53 + 1
  maxPortableInt* =  9007199254740991 # +2**53 - 1

  defaultJsonReaderFlags* = {
    JsonReaderFlag.integerPositiveSign,
    JsonReaderFlag.allowComments,
    JsonReaderFlag.leadingFraction,
    JsonReaderFlag.trailingComma,
  }

  defaultJsonReaderConf* = JsonReaderConf(
    nestedDepthLimit: 512,
    arrayElementsLimit: 0,
    objectMembersLimit: 0,
    integerDigitsLimit: 128,
    fractionDigitsLimit: 128,
    exponentDigitsLimit: 32,
    stringLengthLimit: 0,
  )

{.push gcsafe, raises: [].}

template `==`*(lhs, rhs: JsonString): bool =
  string(lhs) == string(rhs)

template valueType*[K, V](_: type OrderedTable[K, V]): untyped = V

func isFloat*(x: JsonNumber): bool =
  x.fraction.len > 0

func hasExponent*[T](x: JsonNumber[T]): bool =
  when T is string:
    x.exponent.len > 0
  else:
    x.exponent > 0

func toInt*(sign: JsonSign): int =
  case sign:
  of JsonSign.None: 1
  of JsonSign.Pos: 0
  of JsonSign.Neg: -1

func `==`*(lhs, rhs: JsonValueRef): bool =
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
    if lhs.objVal.len != rhs.objVal.len:
      return true
    for k, v in lhs.objVal:
      let rhsVal = rhs.objVal.getOrDefault(k, nil)
      if rhsVal.isNil:
        return false
      if rhsVal != v:
        return false
    true
  of JsonValueKind.Array:
    if lhs.arrayVal.len != rhs.arrayVal.len:
      return false
    for i, x in lhs.arrayVal:
      if x != rhs.arrayVal[i]:
        return false
    true
  of JsonValueKind.Bool:
    lhs.boolVal == rhs.boolVal
  of JsonValueKind.Null:
    true

{.pop.}
