# json-serialization
# Copyright (c) 2024-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2,
  ../json_serialization/pkg/results,
  ../json_serialization/std/options,
  ../json_serialization

type
  ObjectWithOptionalFields = object
    a: Opt[int]
    b: Option[string]
    c: int

  OWOF = object
    a: Opt[int]
    b: Option[string]
    c: int

createJsonFlavor YourJson,
  omitOptionalFields = false

createJsonFlavor MyJson,
  omitOptionalFields = true

ObjectWithOptionalFields.useDefaultSerializationIn YourJson
ObjectWithOptionalFields.useDefaultSerializationIn MyJson

type
  FruitX = enum
    BananaX = "BaNaNa"
    AppleX  = "ApplE"
    GrapeX  = "VVV"

  Drawer = enum
    One
    Two

FruitX.configureJsonSerialization(EnumAsString)
Json.configureJsonSerialization(Drawer, EnumAsNumber)
MyJson.configureJsonSerialization(Drawer, EnumAsString)

proc writeValue*(w: var JsonWriter, val: OWOF)
                  {.gcsafe, raises: [IOError].} =
  w.writeObject(OWOF):
    w.writeField("a", val.a)
    w.writeField("b", val.b)
    w.writeField("c", val.c)

func toReader(input: string): JsonReader[DefaultFlavor] =
  var stream = unsafeMemoryInput(input)
  JsonReader[DefaultFlavor].init(stream)

suite "Test writer":
  test "stdlib option top level some YourJson":
    var val = some(123)
    let json = YourJson.encode(val)
    check json == "123"

  test "stdlib option top level none YourJson":
    var val = none(int)
    let json = YourJson.encode(val)
    check json == "null"

  test "stdlib option top level some MyJson":
    var val = some(123)
    let json = MyJson.encode(val)
    check json == "123"

  test "stdlib option top level none MyJson":
    var val = none(int)
    let json = MyJson.encode(val)
    check json == "null"

  test "results option top level some YourJson":
    var val = Opt.some(123)
    let json = YourJson.encode(val)
    check json == "123"

  test "results option top level none YourJson":
    var val = Opt.none(int)
    let json = YourJson.encode(val)
    check json == "null"

  test "results option top level some MyJson":
    var val = Opt.some(123)
    let json = MyJson.encode(val)
    check json == "123"

  test "results option top level none MyJson":
    var val = Opt.none(int)
    let json = MyJson.encode(val)
    check json == "null"

  test "stdlib option array some YourJson":
    var val = [some(123), some(345)]
    let json = YourJson.encode(val)
    check json == "[123,345]"

  test "stdlib option array none YourJson":
    var val = [some(123), none(int), some(777)]
    let json = YourJson.encode(val)
    check json == "[123,null,777]"

  test "stdlib option array some MyJson":
    var val = [some(123), some(345)]
    let json = MyJson.encode(val)
    check json == "[123,345]"

  test "stdlib option array none MyJson":
    var val = [some(123), none(int), some(777)]
    let json = MyJson.encode(val)
    check json == "[123,null,777]"

  test "results option array some YourJson":
    var val = [Opt.some(123), Opt.some(345)]
    let json = YourJson.encode(val)
    check json == "[123,345]"

  test "results option array none YourJson":
    var val = [Opt.some(123), Opt.none(int), Opt.some(777)]
    let json = YourJson.encode(val)
    check json == "[123,null,777]"

  test "results option array some MyJson":
    var val = [Opt.some(123), Opt.some(345)]
    let json = MyJson.encode(val)
    check json == "[123,345]"

  test "results option array none MyJson":
    var val = [Opt.some(123), Opt.none(int), Opt.some(777)]
    let json = MyJson.encode(val)
    check json == "[123,null,777]"

  test "object with optional fields":
    let x = ObjectWithOptionalFields(
      a: Opt.some(123),
      b: some("nano"),
      c: 456,
    )

    let y = ObjectWithOptionalFields(
      a: Opt.none(int),
      b: none(string),
      c: 999,
    )

    let u = YourJson.encode(x)
    check u == """{"a":123,"b":"nano","c":456}"""

    let v = YourJson.encode(y)
    check v == """{"a":null,"b":null,"c":999}"""

    let xx = MyJson.encode(x)
    check xx == """{"a":123,"b":"nano","c":456}"""

    let yy = MyJson.encode(y)
    check yy == """{"c":999}"""

  test "writeField with object with optional fields":
    let x = OWOF(
      a: Opt.some(123),
      b: some("nano"),
      c: 456,
    )

    let y = OWOF(
      a: Opt.none(int),
      b: none(string),
      c: 999,
    )

    let xx = MyJson.encode(x)
    check xx == """{"a":123,"b":"nano","c":456}"""
    let yy = MyJson.encode(y)
    check yy == """{"c":999}"""

    let uu = YourJson.encode(x)
    check uu == """{"a":123,"b":"nano","c":456}"""
    let vv = YourJson.encode(y)
    check vv == """{"a":null,"b":null,"c":999}"""

  test "Enum value representation primitives":
    when DefaultFlavor.flavorEnumRep() == EnumAsString:
      check true
    elif DefaultFlavor.flavorEnumRep() == EnumAsNumber:
      check false
    elif DefaultFlavor.flavorEnumRep() == EnumAsStringifiedNumber:
      check false

    DefaultFlavor.flavorEnumRep(EnumAsNumber)
    when DefaultFlavor.flavorEnumRep() == EnumAsString:
      check false
    elif DefaultFlavor.flavorEnumRep() == EnumAsNumber:
      check true
    elif DefaultFlavor.flavorEnumRep() == EnumAsStringifiedNumber:
      check false

    DefaultFlavor.flavorEnumRep(EnumAsStringifiedNumber)
    when DefaultFlavor.flavorEnumRep() == EnumAsString:
      check false
    elif DefaultFlavor.flavorEnumRep() == EnumAsNumber:
      check false
    elif DefaultFlavor.flavorEnumRep() == EnumAsStringifiedNumber:
      check true

  test "Enum value representation of DefaultFlavor":
    type
      ExoticFruits = enum
        DragonFruit
        SnakeFruit
        StarFruit

    DefaultFlavor.flavorEnumRep(EnumAsNumber)
    let u = Json.encode(DragonFruit)
    check u == "0"

    DefaultFlavor.flavorEnumRep(EnumAsString)
    let v = Json.encode(SnakeFruit)
    check v == "\"SnakeFruit\""

    DefaultFlavor.flavorEnumRep(EnumAsStringifiedNumber)
    let w = Json.encode(StarFruit)
    check w == "\"2\""

  test "EnumAsString of DefaultFlavor/Json":
    type
      Fruit = enum
        Banana = "BaNaNa"
        Apple  = "ApplE"
        JackFruit = "VVV"

      ObjectWithEnumField = object
        fruit: Fruit

    Json.flavorEnumRep(EnumAsString)
    let u = Json.encode(Banana)
    check u == "\"BaNaNa\""

    let v = Json.encode(Apple)
    check v == "\"ApplE\""

    let w = Json.encode(JackFruit)
    check w == "\"VVV\""

    Json.flavorEnumRep(EnumAsStringifiedNumber)
    let x = Json.encode(JackFruit)
    check x == "\"2\""

    Json.flavorEnumRep(EnumAsNumber)
    let z = Json.encode(Banana)
    check z == "0"

    let obj = ObjectWithEnumField(fruit: Banana)
    let zz = Json.encode(obj)
    check zz == """{"fruit":0}"""

  test "Individual enum configuration":
    Json.flavorEnumRep(EnumAsNumber)
    # Although the flavor config is EnumAsNumber
    # FruitX is configured as EnumAsAstring
    let z = Json.encode(BananaX)
    check z == "\"BaNaNa\""

    # configuration: Json.configureJsonSerialization(Drawer, EnumAsNumber)
    let u = Json.encode(Two)
    check u == "1"

    # configuration: MyJson.configureJsonSerialization(Drawer, EnumAsString)
    let v = MyJson.encode(One)
    check v == "\"One\""

  test "float writer":
    template checkExp(src, res) =
      var x = toReader(src)
      let y = x.readValue(JsonNumber[uint64])
      let z = Json.encode(y)
      check z == res

    checkExp("0.0E-1", "0.0e-1")
    checkExp("+0.1e-2", "0.1e-2")
    checkExp("-0.2e-9", "-0.2e-9")
    checkExp("0.0E+1", "0.0e+1")
    checkExp("+0.1e+2", "0.1e+2")
    checkExp("-0.2e+9", "-0.2e+9")
