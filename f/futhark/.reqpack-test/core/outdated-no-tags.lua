return {
  name = "futhark outdated skips repos without tags",
  request = {
    action = "outdated",
    system = "futhark",
    flags = {
      "cwd=${fixtureRoot}/project",
      "cache-root=${fixtureRoot}/cache",
    },
  },
  fixtureFiles = {
    ["project/futhark.pkg"] = [=[require {
  github.com/diku-dk/array 0.0.0+abcdef
}
]=],
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/project/futhark.pkg'",
      exitCode = 0,
      stdout = [=[require {
  github.com/diku-dk/array 0.0.0+abcdef
}
]=],
      stderr = "",
      success = true,
    },
    {
      match = "test -d '${fixtureRoot}/project/lib/github.com/diku-dk/array'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "command -v 'git' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "git ls-remote --tags --refs 'https://github.com/diku-dk/array'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/cache/metadata'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "printf %s '{\"cachePath\":\"${fixtureRoot}/cache/metadata/github.com_diku-dk_array.json\",\"lastRefreshed\":\"1970-01-01T00:00:00Z\",\"latestVersion\":null,\"name\":\"github.com/diku-dk/array\",\"outdatedCheck\":\"unsupported-no-tags\",\"sourceUrl\":\"https://github.com/diku-dk/array\",\"versionSource\":\"none\",\"versions\":[]}' > '${fixtureRoot}/cache/metadata/github.com_diku-dk_array.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
