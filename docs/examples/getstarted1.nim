{.push gcsafe, raises: [].}

import json_serialization

# ANCHOR: Custom
type JsonRpcId = distinct JsonString

proc readValue*(
    r: var JsonReader, val: var JsonRpcId
) {.raises: [IOError, JsonReaderError].} =
  let tok = r.tokKind
  case tok
  of JsonValueKind.Number, JsonValueKind.String, JsonValueKind.Null:
    # Keep the original value without further processing
    val = JsonRpcId(r.parseAsString())
  else:
    r.raiseUnexpectedValue("Invalid RequestId, got " & $tok)

proc writeValue*(w: var JsonWriter, val: JsonRpcId) {.raises: [IOError].} =
  w.writeValue(JsonString(val)) # Preserve the original content
# ANCHOR_END: Custom

type Request = object
  jsonrpc: string
  `method`: string
  params: seq[int]
  id: JsonRpcId

echo Json.encode(Json.decode("""{"id": "test"}""", Request))
