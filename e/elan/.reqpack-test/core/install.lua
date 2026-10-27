return {
  name = "elan install toolchain",
  request = {
    action = "install",
    system = "elan",
    packages = {
      { action = "install", name = "nightly-2023-09-06" }
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
      match = "elan toolchain install 'nightly-2023-09-06'",
      exitCode = 0,
      stdout = "info: syncing channel updates\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "elan toolchain install 'nightly-2023-09-06'",
    },
    events = { "installed", "success" },
  }
}
