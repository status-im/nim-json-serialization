import
  serialization, json_serialization/[reader, writer]

export
  serialization, reader, writer

serializationFormat Json,
                    Reader = JsonReader,
                    Writer = JsonWriter,
                    PreferedOutput = string,
                    mimeType = "application/json"

