return {
  name = "elan uninstall toolchain",
  request = {
    action = "remove",
    system = "elan",
    packages = {
      { action = "remove", name = "nightly-2023-09-06" }
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
      match = "elan toolchain uninstall 'nightly-2023-09-06'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "elan toolchain uninstall 'nightly-2023-09-06'",
    },
    events = { "deleted", "success" },
  }
}
