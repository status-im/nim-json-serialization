import json_serialization, faststreams/outputs

let file = fileOutput("output.json")
var writer = JsonWriter[DefaultFlavor].init(file, pretty = true)

writer.beginArray()

for i in 0 ..< 2:
  writer.beginObjectElement()

  writer.writeMember("id", i)
  writer.writeMember("name", "item" & $i)

  writer.endObjectElement()

writer.endArray()

file.close()
