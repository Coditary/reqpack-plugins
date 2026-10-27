return {
  name = "eupm remove package",
  request = {
    action = "remove",
    system = "eupm",
    packages = {
      { action = "remove", name = "sequence-utils" }
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
      match = "eupm remove 'sequence-utils'",
      exitCode = 0,
      stdout = "removed sequence-utils\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm remove 'sequence-utils'",
    },
    events = { "deleted", "success" },
  }
}
