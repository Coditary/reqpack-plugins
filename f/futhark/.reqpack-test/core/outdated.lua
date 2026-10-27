return {
  name = "futhark outdated compares manifest with git tags",
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
  github.com/diku-dk/array 1.2.3
}
]=],
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/project/futhark.pkg'",
      exitCode = 0,
      stdout = [=[require {
  github.com/diku-dk/array 1.2.3
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
      stdout = "abc\trefs/tags/v1.2.3\ndef\trefs/tags/v1.3.0\n",
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
      match = "printf %s '{\"cachePath\":\"${fixtureRoot}/cache/metadata/github.com_diku-dk_array.json\",\"lastRefreshed\":\"1970-01-01T00:00:00Z\",\"latestVersion\":\"1.3.0\",\"name\":\"github.com/diku-dk/array\",\"sourceUrl\":\"https://github.com/diku-dk/array\",\"versions\":[\"1.2.3\",\"1.3.0\"]}' > '${fixtureRoot}/cache/metadata/github.com_diku-dk_array.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "github.com/diku-dk/array",
    resultVersion = "1.2.3",
  },
}
