import json_serialization, faststreams/outputs

let file = fileOutput("output.json")
var writer = JsonWriter[DefaultFlavor].init(file, pretty = true)

writer.beginArray()

for i in 0 ..< 2:
  writer.beginObject()

  writer.writeMember("id", i)
  writer.writeMember("name", "item" & $i)

  writer.endObject()

writer.endArray()

file.close()
