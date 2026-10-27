return {
  name = "wasm-bindgen install",
  request = {
    action = "install",
    system = "wasm-bindgen",
    packages = {
      { name = "wasm-bindgen" }
    },
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
      match = "cargo install --color never wasm-bindgen-cli",
      exitCode = 0,
      stdout = "install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v cargo >/dev/null 2>&1",
      "cargo install --color never wasm-bindgen-cli"
    },
    stdout = {
      "install ok\n"
    },
    events = { "installed", "success" },
  }
}
