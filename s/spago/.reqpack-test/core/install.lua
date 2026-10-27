return {
  name = "spago install dependencies",
  request = {
    action = "install",
    system = "spago",
    packages = {
      { name = "prelude", version = "6.0.2" },
      { name = "effect", version = "4.0.0" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'spago' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spago install prelude effect",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'spago' >/dev/null 2>&1",
      "spago install prelude effect",
    },
    events = { "installed", "success" },
  }
}
