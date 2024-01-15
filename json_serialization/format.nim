# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  serialization/[formats, object_serialization]

export
  formats

serializationFormat Json,
                    mimeType = "application/json"

template supports*(_: type Json, T: type): bool =
  # The JSON format should support every type
  true

template flavorUsesAutomaticObjectSerialization*(T: type DefaultFlavor): bool = true
template flavorOmitsOptionalFields*(T: type DefaultFlavor): bool = false
template flavorRequiresAllFields*(T: type DefaultFlavor): bool = false
template flavorAllowsUnknownFields*(T: type DefaultFlavor): bool = false
template flavorSkipNullFields*(T: type DefaultFlavor): bool = false

# We create overloads of these traits to force the mixin treatment of the symbols
type DummyFlavor* = object
template flavorUsesAutomaticObjectSerialization*(T: type DummyFlavor): bool = true
template flavorOmitsOptionalFields*(T: type DummyFlavor): bool = false
template flavorRequiresAllFields*(T: type DummyFlavor): bool = false
template flavorAllowsUnknownFields*(T: type DummyFlavor): bool = false
template flavorSkipNullFields*(T: type DummyFlavor): bool = false

template createJsonFlavor*(FlavorName: untyped,
                           mimeTypeValue = "application/json",
                           automaticObjectSerialization = false,
                           requireAllFields = true,
                           omitOptionalFields = true,
                           allowUnknownFields = true,
                           skipNullFields = false) {.dirty.} =
  type FlavorName* = object

  template Reader*(T: type FlavorName): type = Reader(Json, FlavorName)
  template Writer*(T: type FlavorName): type = Writer(Json, FlavorName)
  template PreferredOutputType*(T: type FlavorName): type = string
  template mimeType*(T: type FlavorName): string = mimeTypeValue

  template flavorUsesAutomaticObjectSerialization*(T: type FlavorName): bool = automaticObjectSerialization
  template flavorOmitsOptionalFields*(T: type FlavorName): bool = omitOptionalFields
  template flavorRequiresAllFields*(T: type FlavorName): bool = requireAllFields
  template flavorAllowsUnknownFields*(T: type FlavorName): bool = allowUnknownFields
  template flavorSkipNullFields*(T: type FlavorName): bool = skipNullFields
