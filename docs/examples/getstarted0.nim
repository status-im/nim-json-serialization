# ANCHOR: Import
{.push gcsafe, raises: [].} # Encourage exception handling hygiene in procedures!

import json_serialization
export json_serialization
# ANCHOR_END: Import

# ANCHOR: Request
type Request = object
  jsonrpc: string
  `method`: string # Quote Nim keywords
  params: seq[int] # Map JSON array to `seq`
  id: int

# ANCHOR_END: Request

# ANCHOR: Decode
# Decode the string into our Request type
let decoded = Json.decode(
  """{"jsonrpc": "2.0", "method": "subtract", "params": [42, 3], "id": 1}""", Request
)

echo decoded.id
# ANCHOR_END: Decode

# ANCHOR: Pretty
# Now that we have a `Request` instance, we can pretty-print it:
echo Json.encode(decoded, pretty = true)
# ANCHOR_END: Pretty

# ANCHOR: Errors
try:
  # Oops, a string was used for the `id` field!
  discard Json.decode("""{"id": "test"}""", Request)
except JsonError as exc:
  # "<string>" helps identify the source of the document - this can be a
  # filename, URL or something else that helps the user find the error
  echo "Failed to parse document: ", exc.formatMsg("<string>")
# ANCHOR_END: Errors
