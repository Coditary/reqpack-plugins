return {
  name = "eupm outdated empty by design",
  request = {
    action = "outdated",
    system = "eupm",
  },
  fakeExec = {
    {
      match = "command -v eupm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {},
    events = { "outdated" },
    resultCount = 0,
  }
}
