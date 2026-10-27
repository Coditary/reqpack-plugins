return {
  name = "wasm-bindgen remove tool",
  request = {
    action = "remove",
    system = "wasm-bindgen",
    packages = {
      { name = "wasm-bindgen-cli" }
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
      match = "cargo uninstall wasm-bindgen-cli --color never",
      exitCode = 0,
      stdout = "remove ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v cargo >/dev/null 2>&1",
      "cargo uninstall wasm-bindgen-cli --color never"
    },
    events = { "deleted", "success" },
  }
}
