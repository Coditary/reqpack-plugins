return {
  name = "wasm-bindgen update",
  request = {
    action = "update",
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
      match = "cargo install --color never --force wasm-bindgen-cli",
      exitCode = 0,
      stdout = "update ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v cargo >/dev/null 2>&1",
      "cargo install --color never --force wasm-bindgen-cli"
    },
    events = { "updated", "success" },
  }
}
