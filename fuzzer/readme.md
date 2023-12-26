## Fuzz test manual

You need to install [testutils](https://github.com/status-im/nim-testutils) and
[chronicles](https://github.com/status-im/nim-chronicles).
Then read documentation over there to prepare your execution environment.

### Compatibility

These fuzzers can be compiled with Nim v1.6.16 or newer.

### Available fuzz test

* fuzz_lexer
* fuzz_parser

### Manually with libFuzzer/llvmFuzer
#### Compiling
```sh
nim c -d:llvmFuzzer -d:release -d:chronicles_log_level=FATAL --noMain --cc=clang --passC="-fsanitize=fuzzer" --passL="-fsanitize=fuzzer" fuzzer/fuzz_lexer
```

#### Starting the Fuzzer
Starting the fuzzer is as simple as running the compiled program:
```sh
./fuzz_lexer corpus_dir -runs=1000000
```

To see the available options:
```sh
./fuzz_lexer test=1
```

You can also use the application to verify a specific test case:
```sh
./fuzz_lexer input_file
```
