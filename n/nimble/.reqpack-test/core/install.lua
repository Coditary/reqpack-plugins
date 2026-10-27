return {
  name = "nimble install package",
  request = {
    action = "install",
    system = "nimble",
    packages = {
      { action = "install", name = "jester" }
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
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --accept --noColor install 'jester'",
      exitCode = 0,
      stdout = "Success: jester installed successfully.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "nimble --accept --noColor install 'jester'"
    },
    events = { "installed", "success" },
  }
}
