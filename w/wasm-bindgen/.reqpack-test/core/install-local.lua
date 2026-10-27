return {
  name = "wasm-bindgen install local",
  request = {
    action = "install",
    system = "wasm-bindgen",
    localPath = "${fixtureRoot}/input/app.wasm",
    flags = {
      "cache-root=${fixtureRoot}/.reqpack-data/wasm-bindgen",
      "out-dir=${fixtureRoot}/generated-out",
    },
  },
  fixtureDirs = {
    "input",
  },
  fixtureFiles = {
    {
      path = "input/app.wasm",
      content = "wasm-bytes",
    },
  },
  fakeExec = {
    {
      match = "command -v wasm-bindgen >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "wasm-bindgen '${fixtureRoot}/input/app.wasm' --out-dir '${fixtureRoot}/generated-out' --target bundler",
      exitCode = 0,
      stdout = "generated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v wasm-bindgen >/dev/null 2>&1",
      "wasm-bindgen '${fixtureRoot}/input/app.wasm' --out-dir '${fixtureRoot}/generated-out' --target bundler"
    },
    events = { "installed", "success" },
  }
}
