return {
  name = "corral search unsupported",
  request = {
    action = "search",
    system = "corral",
    prompt = "valbytes",
  },
  fakeExec = {
    {
      match = "command -v 'corral' >/dev/null 2>&1",
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
  },
}
