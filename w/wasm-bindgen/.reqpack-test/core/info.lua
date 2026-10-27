return {
  name = "wasm-bindgen info tool",
  request = {
    action = "info",
    system = "wasm-bindgen",
    prompt = "wasm-bindgen",
  },
  fakeExec = {
    {
      match = "command -v cargo >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cargo install --list --quiet --color never",
      exitCode = 0,
      stdout = "wasm-bindgen-cli v0.2.122:\n    wasm-bindgen\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v cargo >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cargo info wasm-bindgen-cli --quiet --color never",
      exitCode = 0,
      stdout = "wasm-bindgen-cli #wasm #webassembly\nCommand line interface for wasm-bindgen\nversion: 0.2.122\nlicense: MIT OR Apache-2.0\ndocumentation: https://wasm-bindgen.github.io/wasm-bindgen/\nhomepage: https://wasm-bindgen.github.io/wasm-bindgen/\nrepository: https://github.com/rustwasm/wasm-bindgen\ncrates.io: https://crates.io/crates/wasm-bindgen-cli/0.2.122\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "wasm-bindgen-cli",
    resultVersion = "0.2.122",
  }
}
