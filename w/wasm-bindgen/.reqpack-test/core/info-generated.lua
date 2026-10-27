return {
  name = "wasm-bindgen info generated",
  request = {
    action = "info",
    system = "wasm-bindgen",
    flags = {
      "cache-root=${fixtureRoot}/.reqpack-data/wasm-bindgen",
    },
    prompt = "generated:test-key",
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
    events = { "informed" },
    resultCount = 1,
    resultName = "app.wasm",
    resultVersion = "bundler",
    commands = {
      "find '${fixtureRoot}/.reqpack-data/wasm-bindgen/generated' -type f -name 'manifest.json' | LC_ALL=C sort",
      "cat '${fixtureRoot}/.reqpack-data/wasm-bindgen/generated/test-key/manifest.json'"
    },
  }
}
