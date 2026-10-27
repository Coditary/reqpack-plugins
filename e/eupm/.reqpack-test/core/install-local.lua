return {
  name = "eupm install local path",
  request = {
    action = "installLocal",
    system = "eupm",
    localPath = "./fixtures/localpkg",
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
      match = "eupm install './fixtures/localpkg'",
      exitCode = 0,
      stdout = "installed ./fixtures/localpkg\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm install './fixtures/localpkg'",
    },
    events = { "installed", "success" },
  }
}
