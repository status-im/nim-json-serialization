import
  serialization/errors

export
  errors

type
  JsonMode* = enum
    Relaxed
    Portable

  JsonError* = object of SerializationError

const
  defaultJsonMode* = JsonMode.Relaxed
  minPortableInt* = -9007199254740991 # -2**53 + 1
  maxPortableInt* =  9007199254740991 # +2**53 - 1

