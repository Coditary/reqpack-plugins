return {
  name = "raco init fails when binary missing",
  request = {
    action = "list",
    system = "raco",
  },
  fakeExec = {
    {
      match = "command -v 'raco' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "unavailable" },
    resultCount = 0,
  }
}
