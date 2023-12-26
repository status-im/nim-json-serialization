# json-serialization
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

# begin Nimble config (version 1)
when defined(windows):
  when fileExists("nimble-win.paths"):
    include "nimble-win.paths"
  elif fileExists("nimble.paths"):
    include "nimble.paths"
elif defined(linux):
  when fileExists("nimble-win.paths"):
    include "nimble-linux.paths"
  elif fileExists("nimble.paths"):
    include "nimble.paths"
# end Nimble config
