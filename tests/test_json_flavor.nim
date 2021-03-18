import
  strutils,
  serialization,
  ../json_serialization

Json.createFlavor StringyJson

proc writeValue*(w: var JsonWriter[StringyJson], val: SomeInteger) =
  writeValue(w, $val)

proc readValue*(r: var JsonReader[StringyJson], v: var SomeSignedInt) =
  try:
    v = type(v) parseBiggestInt readValue(r, string)
  except ValueError as err:
    r.raiseUnexpectedValue("A signed integer encoded as string")

proc readValue*(r: var JsonReader[StringyJson], v: var SomeUnsignedInt) =
  try:
    v = type(v) parseBiggestUInt readValue(r, string)
  except ValueError as err:
    r.raiseUnexpectedValue("An unsigned integer encoded as string")

type
  Container = object
    name: string
    x: int
    y: uint64
    list: seq[int64]

let c = Container(name: "c", x: -10, y: 20, list: @[1'i64, 2, 25])
let encoded = StringyJson.encode(c)
echo "Encoded: ", encoded

let decoded = try:
  StringyJson.decode(encoded, Container)
except SerializationError as err:
  echo err.formatMsg("<encoded>")
  quit 1

echo "Decoded: ", decoded

