import
  ../../json_serialization, testutils/fuzzing, faststreams/inputs, serialization/testing/tracing

export
  json_serialization, fuzzing

template jsonFuzzingTest*(T: type) =
  test:
    block:
      let input = unsafeMemoryInput(payload)

      let decoded = try: input.readValue(Json, T)
                    except JsonError: break

      if input.len.get > 0:
        # Some unconsumed input remained, this is not a valid test case
        break

      let reEncoded = Json.encode(decoded)

      if $payload != reEncoded:
        when hasSerializationTracing:
          # Run deserialization again to produce a seriazation trace
          # (this is useful for comparing with the initial deserialization)
          discard Json.decode(reEncoded, T)

        echo "Payload with len = ", payload.len
        echo payload
        echo "Re-encoided payload with len = ", reEncoded.len
        echo reEncoded

        echo decoded

        doAssert false
