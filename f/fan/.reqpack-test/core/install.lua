return {
  name = "fan install pod",
  request = {
    action = "install",
    system = "fan",
    packages = {
      { name = "web", version = "1.0.79" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'fanr' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "fanr install -y 'web 1.0.79'",
      exitCode = 0,
      stdout = "Installation successful (1 pods)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'fanr' >/dev/null 2>&1",
      "fanr install -y 'web 1.0.79'",
    },
    events = { "installed", "success" },
  }
}
