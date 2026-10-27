return {
  name = "snap refresh package with channel",
  request = {
    action = "update",
    system = "snap",
    packages = {
      { name = "firefox", flags = { "channel=esr/stable", "classic", "devmode" } }
    },
  },
  fakeExec = {
    {
      match = "command -v 'snap' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "snap refresh 'firefox' --channel='esr/stable'",
      exitCode = 0,
      stdout = "firefox refreshed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
