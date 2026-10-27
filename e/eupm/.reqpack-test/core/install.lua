return {
  name = "eupm install package",
  request = {
    action = "install",
    system = "eupm",
    packages = {
      { action = "install", name = "sequence-utils", version = "1.2.0" }
    },
  },
  fakeExec = {
    {
      match = "command -v eupm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "eupm install 'sequence-utils@1.2.0'",
      exitCode = 0,
      stdout = "installed sequence-utils 1.2.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm install 'sequence-utils@1.2.0'",
    },
    events = { "installed", "success" },
  }
}
