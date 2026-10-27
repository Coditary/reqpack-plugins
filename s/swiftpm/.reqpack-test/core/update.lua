return {
  name = "swiftpm update workspace",
  fixtureRoot = "/tmp/opencode/swiftpm-update",
  request = {
    action = "update",
    system = "swiftpm",
    flags = {
      "data-root=/tmp/opencode/swiftpm-update/data",
      "cache-root=/tmp/opencode/swiftpm-update/cache",
      "config-root=/tmp/opencode/swiftpm-update/config"
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
      match = "cat '/tmp/opencode/swiftpm-update/data/swiftpm/dependencies.tsv'",
      exitCode = 0,
      stdout = "url\tswift-argument-parser\thttps://github.com/apple/swift-argument-parser.git\tfrom\t1.3.0\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-update/data/swiftpm/workspace/Package.resolved'",
      exitCode = 0,
      stdout = [[{"pins":[{"identity":"swift-argument-parser","kind":"remoteSourceControl","location":"https://github.com/apple/swift-argument-parser.git","state":{"revision":"abc123","version":"1.3.2"}}],"version":2}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '/tmp/opencode/swiftpm-update/data/swiftpm/workspace/Package.swift'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/data/swiftpm/home'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/data/swiftpm/workspace'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/cache/swiftpm/cache'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/cache/swiftpm/scratch'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/config/swiftpm/configuration'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/config/swiftpm/security'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/tmp/opencode/swiftpm-update/data/swiftpm'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "HOME='/tmp/opencode/swiftpm-update/data/swiftpm/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' swift package --package-path '/tmp/opencode/swiftpm-update/data/swiftpm/workspace' --cache-path '/tmp/opencode/swiftpm-update/cache/swiftpm/cache' --config-path '/tmp/opencode/swiftpm-update/config/swiftpm/configuration' --security-path '/tmp/opencode/swiftpm-update/config/swiftpm/security' --scratch-path '/tmp/opencode/swiftpm-update/cache/swiftpm/scratch' update",
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
