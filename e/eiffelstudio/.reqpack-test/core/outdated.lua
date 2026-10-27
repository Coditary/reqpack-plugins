return {
  name = "eiffelstudio outdated empty v1",
  request = {
    action = "outdated",
    system = "eiffelstudio",
  },
  fakeExec = {
    {
      match = "command -v iron >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
    },
    events = { "outdated" },
    resultCount = 0,
  }
}
