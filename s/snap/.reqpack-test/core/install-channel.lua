return {
  name = "snap install package with channel",
  request = {
    action = "install",
    system = "snap",
    packages = {
      { name = "firefox", flags = { "channel=latest/stable" } }
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
      match = "snap install 'firefox' --channel='latest/stable'",
      exitCode = 0,
      stdout = "firefox installed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
