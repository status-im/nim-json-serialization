type
  JsonMode* = enum
    Relaxed
    Portable

  JsonError* = object of CatchableError

const
  defaultJsonMode* = JsonMode.Relaxed
  minPortableInt* = -9007199254740991 # -2**53 + 1
  maxPortableInt* =  9007199254740991 # +2**53 - 1

