return {
  name = "eiffelstudio install package",
  request = {
    action = "install",
    system = "eiffelstudio",
    packages = {
      { action = "install", name = "base" }
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
      match = "iron install 'base'",
      exitCode = 0,
      stdout = "Installing package base\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron install 'base'",
    },
    events = { "installed", "success" },
  }
}
