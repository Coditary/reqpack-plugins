return {
  name = "carbon search empty by design",
  request = {
    action = "search",
    system = "carbon",
    prompt = "api",
  },
  fakeExec = {
    {
      match = "command -v 'carbon' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 0,
    events = { "searched" },
  }
}
