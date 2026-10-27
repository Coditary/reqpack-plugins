return {
  name = "gradle search empty",
  request = {
    action = "search",
    system = "gradle",
    prompt = "junit",
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
    events = { "searched" },
    resultCount = 0,
  }
}
