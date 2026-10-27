return {
  name = "hbmk2 outdated unsupported",
  request = {
    action = "outdated",
    system = "hbmk2",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  fakeExec = {
    {
      match = "command -v 'hbmk2' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hbmk2' >/dev/null 2>&1",
    },
    events = { "outdated" },
    resultCount = 0,
  }
}
