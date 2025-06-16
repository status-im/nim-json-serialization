# Getting started

<!-- toc -->

`json_serialization` is used to parse JSON documents directly into Nim types and to encode them back as JSON efficiently.

Let's start with a simple [JSON-RPC](https://www.jsonrpc.org/specification#examples) example:

```json
{"jsonrpc": "2.0", "method": "subtract", "params": [42, 3], "id": 1}
```

## Imports and exports

Before we can use `json_serialization`, we have to import the library.

If you put your custom serialization code in a separate module, make sure to re-export `json_serialization`:

```nim
{{#include ../examples/getstarted0.nim:Import}}
```

A common way to organize serialization code is to use a separate module named either after the library (`mylibrary_json_serialization`) or the flavor (`myflavor_json_serialization`).

For types that mainly exist to interface with JSON, custom serializers can also be placed together with the type definitions.

```admonish tip "Re-exports"
When importing a module that contains custom serializers, make sure to re-export it or you might end up with cryptic compiler errors or worse, the default serializers being used!
```

## Simple reader

Looking at the example, we'll define a Nim `object` to hold the request data, with matching field names and types:

```nim
{{#include ../examples/getstarted0.nim:Request}}
```

`Json.decode` can now turn our JSON input into a `Request`:
```nim
{{#include ../examples/getstarted0.nim:Decode}}
```

```admonish tip ""
Replace `decode`/`encode` with `loadFile`/`saveFile` to read and write a file instead!
```

## Encoding and pretty printing

Having parsed the example with `Json.decode`, we can pretty-print it back to the console using `Json.encode` that returns a `string`:

```nim
{{#include ../examples/getstarted0.nim:Pretty}}
```

## Handling errors

Of course, someone might give us some invalid data - `json_serialization` will raise an exception when that happens:

```nim
{{#include ../examples/getstarted0.nim:Errors}}
```

The error message points out where things went wrong:

```text
Failed to parse document: <string>(1, 8) number expected
```

## Custom parsing

Happy we averted a crisis by adding the forgotten exception handler, we go back to the [JSON-RPC specification](https://www.jsonrpc.org/specification#request_object) and notice that strings are actually allowed in the `id` field - further, the only thing we have to do with `id` is to pass it back in the response - we don't really care about its contents.

We'll define a helper type to deal with this situation and attach some custom parsing code to it that checks the type. Using `JsonString` as underlying storage is an easy way to pass around snippets of JSON whose contents we don't need.

The custom code is added to `readValue`/`writeValue` procedures that take the stream and our custom type as arguments:

```nim
{{#include ../examples/getstarted1.nim:Custom}}
```

## Flavors and strictness

While the defaults that `json_serialization` offers are sufficient to get started, implementing JSON-based standards often requires more fine-grained control, such as what to do when a field is missing, unknown or has high-level requirements for parsing and formatting.

We use `createJsonFlavor` to declare the new flavor passing to it the customization options that we're interested in:

```nim
{{#include ../examples/getstarted2.nim:Create}}
```

## Required and optional fields

In the JSON-RPC example, both the `jsonrpc` version tag and `method` are required while parameters and `id` can be omitted. Our flavor required all fields to be present except those explicitly optional - we use `Opt` from [results](https://github.com/arnetheduck/nim-results) to select the optional ones:

```nim
{{#include ../examples/getstarted2.nim:Request}}
```

## Automatic object conversion

The default `Json` flavor allows any `object` to be converted to JSON. If you define a custom serializer and someone forgets to import it, the compiler might end up using the default instead resulting in a nasty runtime surprise.

`automaticObjectSerialization = false` forces a compiler error for any type that has not opted in to be serialized:

```nim
{{#include ../examples/getstarted2.nim:Auto}}
```

With all that work done, we can finally use our custom flavor to encode and decode the `Request`:

```nim
{{#include ../examples/getstarted2.nim:Encode}}
```

## ...almost there!

While we've covered a fair bit of ground already, our `Request` parser is still not fully standards-compliant - in particular, the list of parameters must be able to handle both positional and named arguments and the values can themselves be full JSON documents that need custom parsing based on the `method` value.

A more mature JSON-RPC parser can be found in [nim-json-rpc](https://github.com/status-im/nim-json-rpc/blob/master/json_rpc/private/jrpc_sys.nim) which connects the `json_serialization` library to a DSL that conveniently allows mapping Nim procedures to JSON-RPC methods, featuring automatic parameter conversion and other nice conveniences..

Furtyher examples of how to use `json_serialization` can be found in the `tests` folder.

```admonish tip "Read that spec!"
Not only did we learn to about `json_serialization`, but also that examples are no substitute for reading the spec!
```
