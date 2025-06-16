import std/json, json_serialization

# ANCHOR: Decode
const rawJson = """{"name": "localhost", "port": 42}"""
type
  NimServer = object
    name: string
    port: int

  MixedServer = object
    name: JsonValueRef[uint64]
    port: int

  StringServer = object
    name: JsonString
    port: JsonString

var conf = defaultJsonReaderConf
conf.nestedDepthLimit = 0

let native =
  Json.decode(rawJson, NimServer, flags = defaultJsonReaderFlags, conf = conf)

# decode into native Nim
#let native = Json.decode(rawJson, NimServer)

# decode into mixed Nim + JsonValueRef
let mixed = Json.decode(rawJson, MixedServer)

# decode any value into nested json string
let str = Json.decode(rawJson, StringServer)

# decode any valid JSON, using the `json_serialization` node type
let value = Json.decode(rawJson, JsonValueRef[uint64])

# decode any valid JSON, using the `std/json` node type
let stdjson = Json.decode(rawJson, JsonNode)

# read JSON document from file instead
let file = Json.loadFile("filename.json", NimServer)
# ANCHOR_END: Decode

# ANCHOR: Reader
var reader = JsonReader[DefaultFlavor].init(memoryInput(rawJson))
let native2 = reader.readValue(NimServer)

# Overwrite an existing instance
var reader2 = JsonReader[DefaultFlavor].init(memoryInput(rawJson))
var native3: NimServer
reader2.readValue(native3)
# ANCHOR_END: Reader

# ANCHOR: Encode
# Convert object to string
echo Json.encode(native)

# Write JSON to file
Json.saveFile("filename.json", native)

# Pretty-print a tuple
echo Json.encode((x: 4, y: 5), pretty = true)
# ANCHOR_END: Encode

# ANCHOR: Writer
var output = memoryOutput()
var writer = JsonWriter[DefaultFlavor].init(output)
writer.writeValue(native)
echo output.getOutput(string)
# ANCHOR_END: Writer
