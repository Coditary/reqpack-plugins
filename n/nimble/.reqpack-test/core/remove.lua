return {
  name = "nimble remove package",
  request = {
    action = "remove",
    system = "nimble",
    packages = {
      { action = "remove", name = "jester" }
    },
  },
  fakeExec = {
    {
      match = "command -v nimble >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --noColor list -i",
      exitCode = 0,
      stdout = "jester  [0.6.0]\n",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --accept --noColor uninstall 'jester'",
      exitCode = 0,
      stdout = "Success: jester uninstalled successfully.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "nimble --accept --noColor uninstall 'jester'"
    },
    events = { "deleted", "success" },
  }
}
