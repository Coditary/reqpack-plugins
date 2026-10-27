return {
  name = "wasm-bindgen install version",
  request = {
    action = "install",
    system = "wasm-bindgen",
    packages = {
      { name = "wasm-bindgen-cli", version = "0.2.122" }
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
      match = "cargo install --color never --version 0.2.122 wasm-bindgen-cli",
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
      "cargo install --color never --version 0.2.122 wasm-bindgen-cli"
    },
    events = { "installed", "success" },
  }
}
