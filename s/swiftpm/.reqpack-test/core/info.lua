return {
  name = "swiftpm info installed and collection metadata",
  fixtureRoot = "/tmp/opencode/swiftpm-info",
  request = {
    action = "info",
    system = "swiftpm",
    prompt = "swift-argument-parser",
    flags = {
      "data-root=/tmp/opencode/swiftpm-info/data",
      "cache-root=/tmp/opencode/swiftpm-info/cache",
      "config-root=/tmp/opencode/swiftpm-info/config"
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
      match = "cat '/tmp/opencode/swiftpm-info/data/swiftpm/dependencies.tsv'",
      exitCode = 0,
      stdout = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-info/data/swiftpm/workspace/Package.resolved'",
      exitCode = 0,
      stdout = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/opencode/swiftpm-info/data/swiftpm/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' swift package-collection search --json --keywords 'swift-argument-parser'",
      exitCode = 0,
      stdout = [[{"packages":[{"url":"https://github.com/apple/swift-argument-parser.git","summary":"Argument parser","versions":[{"version":"1.4.0"}],"packageName":"swift-argument-parser"}]}]],
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/opencode/swiftpm-info/data/swiftpm/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' swift package-collection describe --json 'https://github.com/apple/swift-argument-parser.git'",
      exitCode = 0,
      stdout = [[{"url":"https://github.com/apple/swift-argument-parser.git","summary":"Argument parser","versions":[{"version":"1.4.0"},{"version":"1.3.2"}],"packageName":"swift-argument-parser","readmeURL":"https://github.com/apple/swift-argument-parser","license":{"name":"Apache-2.0"}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "swift-argument-parser",
    resultVersion = "1.3.2",
  }
}
