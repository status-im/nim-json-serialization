mode = ScriptMode.Verbose

packageName   = "json_serialization"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "JSON serialization without relying on run-time type information"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 0.17.0",
         "ranges"

proc configForTests() =
  --hints: off
  --debuginfo
  --path: "."
  --run

task test, "run tests":
  configForTests()
  setCommand "c", "tests/all.nim"

