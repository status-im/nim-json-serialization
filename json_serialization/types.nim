# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  serialization/errors

export
  errors

type
  JsonMode* = enum
    Relaxed
    Portable

  JsonError* = object of SerializationError

  JsonString* = distinct string

const
  defaultJsonMode* = JsonMode.Relaxed
  minPortableInt* = -9007199254740991 # -2**53 + 1
  maxPortableInt* =  9007199254740991 # +2**53 - 1

template `==`*(lhs, rhs: JsonString): bool =
  string(lhs) == string(rhs)
