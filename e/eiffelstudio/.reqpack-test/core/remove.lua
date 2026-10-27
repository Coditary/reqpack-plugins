return {
  name = "eiffelstudio remove package",
  request = {
    action = "remove",
    system = "eiffelstudio",
    packages = {
      { action = "remove", name = "base" }
    },
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
      match = "iron remove 'base'",
      exitCode = 0,
      stdout = "Removing package base\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron remove 'base'",
    },
    events = { "deleted", "success" },
  }
}
