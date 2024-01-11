# json-serialization
# Copyright (c) 2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2,
  ../json_serialization/stew/results,
  ../json_serialization/std/options,
  ../json_serialization

createJsonFlavor YourJson,
  omitOptionalFields = false

createJsonFlavor MyJson,
  omitOptionalFields = true

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
