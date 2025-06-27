import json_serialization, faststreams/outputs

let file = fileOutput("output.json")
var writer = JsonWriter[DefaultFlavor].init(file)

# ANCHOR: Nesting
writer.writeObject:
  writer.writeMember("status", "ok")
  writer.writeArrayMember("data"):
    for i in 0 ..< 2:
      writer.writeObjectElement:
        writer.writeMember("id", i)
        writer.writeMember("name", "item" & $i)
# ANCHOR_END: Nesting

file.close()
