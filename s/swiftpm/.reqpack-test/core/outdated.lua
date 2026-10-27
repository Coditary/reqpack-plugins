return {
  name = "swiftpm outdated dependency",
  fixtureRoot = "/tmp/opencode/swiftpm-outdated",
  request = {
    action = "outdated",
    system = "swiftpm",
    flags = {
      "data-root=/tmp/opencode/swiftpm-outdated/data",
      "cache-root=/tmp/opencode/swiftpm-outdated/cache",
      "config-root=/tmp/opencode/swiftpm-outdated/config"
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fixtureFiles = {
    {
      path = "data/swiftpm/dependencies.tsv",
      content = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\n",
    },
    {
      path = "data/swiftpm/workspace/Package.resolved",
      content = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
    },
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
      match = "cat '/tmp/opencode/swiftpm-outdated/data/swiftpm/dependencies.tsv'",
      exitCode = 0,
      stdout = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-outdated/data/swiftpm/workspace/Package.resolved'",
      exitCode = 0,
      stdout = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/opencode/swiftpm-outdated/data/swiftpm/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' swift package-collection describe --json 'https://github.com/apple/swift-argument-parser.git'",
      exitCode = 0,
      stdout = [[{"url":"https://github.com/apple/swift-argument-parser.git","summary":"Argument parser","versions":[{"version":"1.4.0"},{"version":"1.3.2"}],"packageName":"swift-argument-parser"}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "swift-argument-parser",
    resultVersion = "1.3.2",
  }
}
