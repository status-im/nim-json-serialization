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

```admonish warning "Elements in objects and array"
In the example, we see `beginArray`, `beginElement` and `writeMember`. The functions follow a pattern:
* functions without suffix, like `beginArray`, are used at the top-level
* functions with `Element` suffix are used inside arrays
* functions with `Member` suffix and accomanying name are used in objects

Thus, if we were writing an array inside another array, we would have used `beginArray` for the outer array and `beginArrayMember` for the inner array. These rules also apply when implementing `writeValue`.
```

### Example: Writing Nested Structures

Objects and arrays can be nested arbitrarily.

Here is the same array of JSON objects, nested in an envelope containing an additional `status` field.

Instead of manually placing `begin`/`end` pairs, we're using the convenience helpers `writeObjectElement` and `writeArrayMember`, along with `writeElement` to manage the required element markers:

```nim
{{#include ../examples/streamwrite1.nim:Nesting}}
```

This produces a the following output - notice the more compact representation when `pretty = true` is not used:
```json
{"status":"ok","data":[{"id":0,"name":"item0"},{"id":1,"name":"item1"}]}
```

```admonish tip
Similar to `begin`, we're using the `Element` suffix in arrays!
```
