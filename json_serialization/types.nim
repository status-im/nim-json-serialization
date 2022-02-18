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

