return {
  name = "fan update targeted pod",
  request = {
    action = "update",
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
      match = "fanr install -y 'web'",
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
      "fanr install -y 'web'",
    },
    events = { "updated", "success" },
  }
}
