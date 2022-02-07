import os except dirExists
import strformat, confutils
import testutils/fuzzing_engines

const
  gitRoot = thisDir() / ".."

  fuzzingTestsDir = gitRoot / "tests" / "fuzzing"
  fuzzingCorpusesDir = fuzzingTestsDir / "corpus"

cli do (testname {.argument.}: string,
        fuzzer = defaultFuzzingEngine):

  let corpusDir = fuzzingCorpusesDir / testname

  rmDir corpusDir
  mkDir corpusDir

  let testProgram = fuzzingTestsDir / &"json_decode_{testname}.nim"
  exec &"""ntu fuzz --fuzzer={fuzzer} --corpus="{corpusDir}" "{testProgram}" """
