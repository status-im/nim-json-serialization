import
  serialization/formats

serializationFormat Json,
                    mimeType = "application/json"

template supports*(_: type Json, T: type): bool =
  # The JSON format should support every type
  true

template useAutomaticObjectSerialization*(T: type DefaultFlavor): bool = true

template createJsonFlavor*(FlavorName: untyped,
                           mimeTypeValue = "application/json",
                           automaticObjectSerialization = false) {.dirty.} =
  type FlavorName* = object
  template Reader*(T: type FlavorName): type = Reader(Json, FlavorName)
  template Writer*(T: type FlavorName): type = Writer(Json, FlavorName)
  template PreferredOutputType*(T: type FlavorName): type = string
  template mimeType*(T: type FlavorName): string = mimeTypeValue
  template useAutomaticObjectSerialization*(T: type FlavorName): bool = automaticObjectSerialization
