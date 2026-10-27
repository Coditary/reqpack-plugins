return {
  name = "swiftpm list resolved dependencies",
  fixtureRoot = "/tmp/opencode/swiftpm-list",
  request = {
    action = "list",
    system = "swiftpm",
    flags = {
      "data-root=/tmp/opencode/swiftpm-list/data",
      "cache-root=/tmp/opencode/swiftpm-list/cache",
      "config-root=/tmp/opencode/swiftpm-list/config"
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fixtureFiles = {
    {
      path = "data/swiftpm/dependencies.tsv",
      content = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\npath\tlocal-package\t/tmp/local-swift-package\t\t\t\n",
    },
    {
      path = "data/swiftpm/workspace/Package.resolved",
      content = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
    },
  },
  fakeExec = {
    {
      match = "cat '/tmp/opencode/swiftpm-list/data/swiftpm/dependencies.tsv'",
      exitCode = 0,
      stdout = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\npath\tlocal-package\t/tmp/local-swift-package\t\t\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-list/data/swiftpm/workspace/Package.resolved'",
      exitCode = 0,
      stdout = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "local-package",
    resultVersion = "local",
  }
}
