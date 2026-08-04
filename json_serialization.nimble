# json-serialization
# Copyright (c) 2023-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

mode = ScriptMode.Verbose

packageName   = "json_serialization"
version       = "0.4.4"
author        = "Status Research & Development GmbH"
description   = "Flexible JSON serialization not relying on run-time type information"
license       = "Apache License 2.0"
skipDirs      = @["tests", "fuzzer"]

requires "nim >= 1.6.0",
         "faststreams >= 0.5.0",
         "serialization",
         "stew >= 0.5.1",
         "results"

from std/os import quoteShell
from std/strutils import endsWith

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --outdir:build " &
  quoteShell("--nimcache:build/nimcache/$projectName") &
  " -d:serializationTestAllRountrips" &
  (if NimMajor >= 2: " -d:unittest2Static" else: "")

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " --mm:refc -r", path
  if (NimMajor, NimMinor) > (1, 6):
    build args & " --mm:orc -r", path

task test, "Run all tests":
  for threads in ["--threads:off", "--threads:on"]:
    run threads, "tests/test_all"

task examples, "Build examples":
  # Build book examples
  for file in listFiles("docs/examples"):
    if file.endsWith(".nim"):
      build "--threads:on", file

task docs, "Generate API documentation":
  exec "mdbook build docs"
  exec nimc & " doc " & "--git.url:https://github.com/status-im/nim-json-serialization --git.commit:master --outdir:docs/book/api --project json_serialization"
