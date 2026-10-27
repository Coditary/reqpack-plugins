return {
  name = "eiffelstudio update catalog",
  request = {
    action = "update",
    system = "eiffelstudio",
    packages = {
      { action = "update", name = "base" }
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
      match = "iron update",
      exitCode = 0,
      stdout = "Updating repositories\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v iron >/dev/null 2>&1",
      "iron update",
    },
    events = { "updated", "success" },
  }
}
