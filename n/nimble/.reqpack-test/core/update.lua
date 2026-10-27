return {
  name = "nimble update package",
  request = {
    action = "update",
    system = "nimble",
    packages = {
      { action = "update", name = "jester" }
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
      stdout = "jester  [0.5.0]\n",
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
    events = { "updated", "success" },
  }
}
