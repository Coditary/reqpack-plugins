return {
  name = "swiftpm remove dependency",
  fixtureRoot = "/tmp/opencode/swiftpm-remove",
  request = {
    action = "remove",
    system = "swiftpm",
    flags = {
      "data-root=/tmp/opencode/swiftpm-remove/data",
      "cache-root=/tmp/opencode/swiftpm-remove/cache",
      "config-root=/tmp/opencode/swiftpm-remove/config"
    },
    packages = {
      { name = "swift-argument-parser" }
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
      match = "cat '/tmp/opencode/swiftpm-remove/data/swiftpm/dependencies.tsv'",
      exitCode = 0,
      stdout = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-remove/data/swiftpm/workspace/Package.resolved'",
      exitCode = 0,
      stdout = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-remove/data/swiftpm/workspace/Package.swift'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/data/swiftpm/home'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/data/swiftpm/workspace'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/cache/swiftpm/cache'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/cache/swiftpm/scratch'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/config/swiftpm/configuration'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/config/swiftpm/security'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-remove/data/swiftpm'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/opencode/swiftpm-remove/data/swiftpm/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' swift package --package-path '/tmp/opencode/swiftpm-remove/data/swiftpm/workspace' --cache-path '/tmp/opencode/swiftpm-remove/cache/swiftpm/cache' --config-path '/tmp/opencode/swiftpm-remove/config/swiftpm/configuration' --security-path '/tmp/opencode/swiftpm-remove/config/swiftpm/security' --scratch-path '/tmp/opencode/swiftpm-remove/cache/swiftpm/scratch' resolve",
      exitCode = 0,
      stdout = "resolved\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
