return {
  name = "gradle outdated empty",
  request = {
    action = "outdated",
    system = "gradle",
  },
  fakeExec = {
    {
      match = "command -v gradle >/dev/null 2>&1",
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
