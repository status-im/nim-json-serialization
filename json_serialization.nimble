mode = ScriptMode.Verbose

packageName   = "json_serialization"
version       = "0.1.5"
author        = "Status Research & Development GmbH"
description   = "Flexible JSON serialization not relying on run-time type information"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.2.0",
         "serialization",
         "stew"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let styleCheckStyle = if (NimMajor, NimMinor) < (1, 6): "hint" else: "error"
let cfg =
  " --styleCheck:usages --styleCheck:" & styleCheckStyle &
  (if verbose: "" else: " --verbosity:0 --hints:off") &
  " --skipParentCfg --skipUserCfg --outdir:build --nimcache:build/nimcache -f" &
  " -d:nimOldCaseObjects"

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

task test, "Run all tests":
  for threads in ["--threads:off", "--threads:on"]:
    run threads, "tests/test_all"
