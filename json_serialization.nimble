mode = ScriptMode.Verbose

packageName   = "json_serialization"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Flexible JSON serialization not relying on run-time type information"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.17.0",
         "serialization",
         "stew"

task test, "Run all tests":
  exec "nim c -r --threads:off tests/test_all"
  exec "nim c -r --threads:on tests/test_all"

