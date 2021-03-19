import
  serialization/formats

serializationFormat Json,
                    mimeType = "application/json"

template supports*(_: type Json, T: type): bool =
  # The JSON format should support every type
  true

