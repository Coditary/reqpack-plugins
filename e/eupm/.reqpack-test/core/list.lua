return {
  name = "eupm list packages",
  request = {
    action = "list",
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
    {
      match = "eupm list",
      exitCode = 0,
      stdout = "sequence-utils 1.2.0\ntext-format 0.8.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm list",
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "sequence-utils",
    resultVersion = "1.2.0",
  }
}
