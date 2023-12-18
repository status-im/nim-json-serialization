# json-serialization
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.experimental: "notnil".}

import
  std/[strformat],
  faststreams/inputs,
  serialization/[formats, errors, object_serialization],
  "."/[format, types, lexer]

export
  inputs, format, types, errors,
  DefaultFlavor

type
  JsonReader*[Flavor = DefaultFlavor] = object
    lex*: JsonLexer

  JsonReaderError* = object of JsonError
    line*, col*: int

  UnexpectedField* = object of JsonReaderError
    encounteredField*: string
    deserializedType*: cstring

  ExpectedTokenCategory* = enum
    etValue = "value"
    etBool = "bool literal"
    etInt = "integer"
    etEnumAny = "enum value (int / string)"
    etEnumString = "enum value (string)"
    etNumber = "number"
    etString = "string"
    etComma = "comma"
    etColon = "colon"
    etBracketLe = "array start bracket"
    etBracketRi = "array end bracker"
    etCurrlyLe = "object start bracket"
    etCurrlyRi = "object end bracket"

  GenericJsonReaderError* = object of JsonReaderError
    deserializedField*: string
    innerException*: ref CatchableError

  UnexpectedTokenError* = object of JsonReaderError
    encountedToken*: JsonValueKind
    expectedToken*: ExpectedTokenCategory

  UnexpectedValueError* = object of JsonReaderError

  IncompleteObjectError* = object of JsonReaderError
    objectType: cstring

  IntOverflowError* = object of JsonReaderError
    isNegative: bool
    absIntVal: BiggestUint

Json.setReader JsonReader

{.push gcsafe, raises: [].}

func valueStr(err: ref IntOverflowError): string =
  if err.isNegative:
    result.add '-'
  result.add($err.absIntVal)

template tryFmt(expr: untyped): string =
  try: expr
  except CatchableError as err: err.msg

method formatMsg*(err: ref JsonReaderError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Error while reading json file: {err.msg}"

method formatMsg*(err: ref UnexpectedField, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Unexpected field '{err.encounteredField}' while deserializing {err.deserializedType}"

method formatMsg*(err: ref UnexpectedTokenError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Unexpected token '{err.encountedToken}' in place of '{err.expectedToken}'"

method formatMsg*(err: ref GenericJsonReaderError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Exception encountered while deserializing '{err.deserializedField}': [{err.innerException.name}] {err.innerException.msg}"

method formatMsg*(err: ref IntOverflowError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) The value '{err.valueStr}' is outside of the allowed range"

method formatMsg*(err: ref UnexpectedValueError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) {err.msg}"

method formatMsg*(err: ref IncompleteObjectError, filename: string):
    string {.gcsafe, raises: [].} =
  tryFmt: fmt"{filename}({err.line}, {err.col}) Not all required fields were specified when reading '{err.objectType}'"

func assignLineNumber*(ex: ref JsonReaderError, lex: JsonLexer) =
  ex.line = lex.line
  ex.col = lex.tokenStartCol

proc raiseUnexpectedToken*(lex: var JsonLexer, expected: ExpectedTokenCategory)
                          {.noreturn, raises: [JsonReaderError, IOError].} =
  var ex = new UnexpectedTokenError
  ex.assignLineNumber(lex)
  ex.encountedToken = lex.tokKind
  ex.expectedToken = expected
  raise ex

template raiseUnexpectedToken*(reader: JsonReader, expected: ExpectedTokenCategory) =
  raiseUnexpectedToken(reader.lex, expected)

func raiseUnexpectedValue*(
    lex: JsonLexer, msg: string) {.noreturn, raises: [JsonReaderError].} =
  var ex = new UnexpectedValueError
  ex.assignLineNumber(lex)
  ex.msg = msg
  raise ex

template raiseUnexpectedValue*(r: JsonReader, msg: string) =
  raiseUnexpectedValue(r.lex, msg)

func raiseIntOverflow*(
    lex: JsonLexer, absIntVal: BiggestUint, isNegative: bool)
    {.noreturn, raises: [JsonReaderError].} =
  var ex = new IntOverflowError
  ex.assignLineNumber(lex)
  ex.absIntVal = absIntVal
  ex.isNegative = isNegative
  raise ex

template raiseIntOverflow*(r: JsonReader, absIntVal: BiggestUint, isNegative: bool) =
  raiseIntOverflow(r.lex, absIntVal, isNegative)

func raiseUnexpectedField*(
    lex: JsonLexer, fieldName: string, deserializedType: cstring)
    {.noreturn, raises: [JsonReaderError].} =
  var ex = new UnexpectedField
  ex.assignLineNumber(lex)
  ex.encounteredField = fieldName
  ex.deserializedType = deserializedType
  raise ex

template raiseUnexpectedField*(r: JsonReader, fieldName: string, deserializedType: cstring) =
  raiseUnexpectedField(r.lex, fieldName, deserializedType)

func raiseIncompleteObject*(
    lex: JsonLexer, objectType: cstring)
    {.noreturn, raises: [JsonReaderError].} =
  var ex = new IncompleteObjectError
  ex.assignLineNumber(lex)
  ex.objectType = objectType
  raise ex

template raiseIncompleteObject*(r: JsonReader, objectType: cstring) =
  raiseIncompleteObject(r.lex, objectType)

func handleReadException*(lex: JsonLexer,
                          Record: type,
                          fieldName: string,
                          field: auto,
                          err: ref CatchableError) {.raises: [JsonReaderError].} =
  var ex = new GenericJsonReaderError
  ex.assignLineNumber(lex)
  ex.deserializedField = fieldName
  ex.innerException = err
  raise ex

template handleReadException*(r: JsonReader,
                              Record: type,
                              fieldName: string,
                              field: auto,
                              err: ref CatchableError) =
  handleReadException(r.lex, Record, fieldName, field, err)

proc init*(T: type JsonReader,
           stream: InputStream,
           flags: JsonReaderFlags,
           conf: JsonReaderConf = defaultJsonReaderConf): T {.raises: [].} =
  result.lex = JsonLexer.init(stream, flags, conf)

proc init*(T: type JsonReader,
           stream: InputStream,
           allowUnknownFields = false,
           requireAllFields = false): T {.raises: [].} =
  mixin flavorAllowsUnknownFields, flavorRequiresAllFields
  type Flavor = T.Flavor

  var flags = defaultJsonReaderFlags
  if allowUnknownFields or flavorAllowsUnknownFields(Flavor):
    flags.incl JsonReaderFlag.allowUnknownFields
  if requireAllFields or flavorRequiresAllFields(Flavor):
    flags.incl JsonReaderFlag.requireAllFields
  result.lex = JsonLexer.init(stream, flags)

{.pop.}
