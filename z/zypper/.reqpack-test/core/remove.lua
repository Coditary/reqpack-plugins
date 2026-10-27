return {
  name = "zypper remove",
  request = {
    action = "remove",
    system = "zypper",
    packages = {
      { name = "curl" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'zypper' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "zypper --non-interactive remove 'curl'",
      exitCode = 0,
      stdout = "Removing: curl\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
