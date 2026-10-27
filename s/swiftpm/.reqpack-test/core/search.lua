return {
  name = "swiftpm package collection search",
  fixtureRoot = "/tmp/opencode/swiftpm-search",
  request = {
    action = "search",
    system = "swiftpm",
    prompt = "argument parser",
    flags = {
      "data-root=/tmp/opencode/swiftpm-search/data",
      "cache-root=/tmp/opencode/swiftpm-search/cache",
      "config-root=/tmp/opencode/swiftpm-search/config"
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    {
      match = "command -v 'swift' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/opencode/swiftpm-search/data/swiftpm/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' swift package-collection search --json --keywords 'argument parser'",
      exitCode = 0,
      stdout = [[{"packages":[{"url":"https://github.com/apple/swift-argument-parser.git","summary":"Argument parser","versions":[{"version":"1.4.0"}],"packageName":"swift-argument-parser"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "swift-argument-parser",
    resultVersion = "1.4.0",
  }
}
