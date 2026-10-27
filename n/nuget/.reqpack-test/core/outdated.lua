return {
  name = "nuget outdated empty",
  request = {
    action = "outdated",
    system = "nuget",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
  },
  fakeExec = {
    {
      match = "command -v 'nuget' >/dev/null 2>&1",
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
  }
}
