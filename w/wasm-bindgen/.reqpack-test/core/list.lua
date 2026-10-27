return {
  name = "wasm-bindgen list",
  request = {
    action = "list",
    system = "wasm-bindgen",
    flags = {
      "cache-root=${fixtureRoot}/.reqpack-data/wasm-bindgen",
    },
  },
  fixtureDirs = {
    ".reqpack-data/wasm-bindgen/generated/test-key/out",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/wasm-bindgen/generated/test-key/manifest.json",
      content = [[{"managedOutput":true,"name":"app.wasm","outputPath":"${fixtureRoot}/.reqpack-data/wasm-bindgen/generated/test-key/out","packageId":"generated:test-key","sourcePath":"${fixtureRoot}/input/app.wasm","target":"bundler","typescript":true}]],
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
      match = "cargo install --list --quiet --color never",
      exitCode = 0,
      stdout = "wasm-bindgen-cli v0.2.122:\n    wasm-bindgen\n",
      stderr = "",
      success = true,
    },
    {
      match = "find '${fixtureRoot}/.reqpack-data/wasm-bindgen/generated' -type f -name 'manifest.json' | LC_ALL=C sort",
      exitCode = 0,
      stdout = "${fixtureRoot}/.reqpack-data/wasm-bindgen/generated/test-key/manifest.json\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/.reqpack-data/wasm-bindgen/generated/test-key/manifest.json'",
      exitCode = 0,
      stdout = [[{"managedOutput":true,"name":"app.wasm","outputPath":"${fixtureRoot}/.reqpack-data/wasm-bindgen/generated/test-key/out","packageId":"generated:test-key","sourcePath":"${fixtureRoot}/input/app.wasm","target":"bundler","typescript":true}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "app.wasm",
  }
}
