{.push gcsafe, raises: [].}

# ANCHOR: Import
import json_serialization, json_serialization/pkg/results
export json_serialization, results
# ANCHOR_END: Import

# ANCHOR: Create
createJsonFlavor JrpcSys,
  automaticObjectSerialization = false,
  requireAllFields = true,
  omitOptionalFields = true, # Don't output `none` values when writing
  allowUnknownFields = false
# ANCHOR_END: Create

# ANCHOR: Custom
type JsonRpcId = distinct JsonString

proc readValue*(
    r: var JsonReader[JrpcSys], val: var JsonRpcId
) {.raises: [IOError, JsonReaderError].} =
  let tok = r.tokKind
  case tok
  of JsonValueKind.Number, JsonValueKind.String, JsonValueKind.Null:
    # Keep the original value without further processing
    val = JsonRpcId(r.parseAsString())
  else:
    r.raiseUnexpectedValue("Invalid RequestId, got " & $tok)

proc writeValue*(w: var JsonWriter[JrpcSys], val: JsonRpcId) {.raises: [IOError].} =
  w.writeValue(JsonString(val)) # Preserve the original content
# ANCHOR_END: Custom

# ANCHOR: Request
type Request = object
  jsonrpc: string
  `method`: string
  params: Opt[seq[int]]
  id: Opt[JsonRpcId]
# ANCHOR_END: Request

# ANCHOR: Auto
# Allow serializing the `Request` type - serializing other types will result in
# a compile-time error because `automaticObjectSerialization` is false!
JrpcSys.useDefaultSerializationFor Request
# ANCHOR_END: Auto

# ANCHOR: Encode
const json = """{"jsonrpc": "2.0", "method": "subtract", "params": [42, 3], "id": 1}"""

echo JrpcSys.encode(JrpcSys.decode(json, Request))
# ANCHOR_END: Encode
