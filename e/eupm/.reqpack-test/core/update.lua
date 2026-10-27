return {
  name = "eupm update package",
  request = {
    action = "update",
    system = "eupm",
    packages = {
      { action = "update", name = "sequence-utils" }
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
      match = "eupm update 'sequence-utils'",
      exitCode = 0,
      stdout = "updated sequence-utils\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm update 'sequence-utils'",
    },
    events = { "updated", "success" },
  }
}
