return {
  name = "eiffelstudio install local package",
  request = {
    action = "installLocal",
    system = "eiffelstudio",
    localPath = "./fixtures/base/package.iron",
  },
  fakeExec = {
    {
      match = "command -v iron >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "iron install './fixtures/base/package.iron'",
      exitCode = 0,
      stdout = "Installing local package\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron install './fixtures/base/package.iron'",
    },
    events = { "installed", "success" },
  }
}
