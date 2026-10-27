return {
  name = "elan update toolchain alias",
  request = {
    action = "update",
    system = "elan",
    packages = {
      { action = "update", name = "stable" }
    },
  },
  fakeExec = {
    {
      match = "command -v elan >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "elan toolchain install 'stable'",
      exitCode = 0,
      stdout = "info: syncing channel updates for 'stable'\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "elan toolchain install 'stable'",
    },
    events = { "updated", "success" },
  }
}
