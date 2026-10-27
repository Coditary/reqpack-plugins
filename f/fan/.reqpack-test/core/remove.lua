return {
  name = "fan remove pod",
  request = {
    action = "remove",
    system = "fan",
    packages = {
      { name = "web" },
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
      match = "fanr uninstall -y 'web'",
      exitCode = 0,
      stdout = "Uninstall successful (1 pods)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'fanr' >/dev/null 2>&1",
      "fanr uninstall -y 'web'",
    },
    events = { "deleted", "success" },
  }
}
