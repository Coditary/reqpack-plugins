return {
  name = "nimble outdated empty",
  request = {
    action = "outdated",
    system = "nimble",
  },
  fakeExec = {
    {
      match = "command -v nimble >/dev/null 2>&1",
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
