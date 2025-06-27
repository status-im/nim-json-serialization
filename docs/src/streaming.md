# Streaming

`JsonWriter` can be used to incrementally write JSON data.

Incremental processing is ideal for large documents or when you want to avoid building the entire JSON structure in memory.

<!-- toc -->

## Writing

You can use `JsonWriter` to write JSON objects, arrays, and values step by step, directly to a file or any output stream.

The process is similar to when you override `writeValue` to provide custom serialization.

### Example: Writing a JSON Array of Objects

Suppose you want to write a large array of objects to a file, one at a time:

```nim
{{#include ../examples/streamwrite0.nim}}
```

Resulting file (`output.json`):
```json
[
  {
    "id": 0,
    "name": "item0"
  },
  {
    "id": 1,
    "name": "item1"
  }
]
```

### Example: Writing Nested Structures

Objects and arrays can be nested arbitrarily.

Here is the same array of JSON objects, nested in an envelope containing an additional `status` field.

Instead of manually placing `begin`/`end` pairs, we're using the convenience helpers `writeObject` and `writeArrayMember`, along with `writeElement` to manage the required element markers:

```ni
{{#include ../examples/streamwrite1.nim:Nesting}}
```

This produces a the following output - notice the more compact representation when `pretty = true` is not used:
```json
{"status":"ok","data":[{"id":0,"name":"item0"},{"id":1,"name":"item1"}]}
```
