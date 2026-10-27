return {
  name = "zypper update",
  request = {
    action = "update",
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
      match = "zypper --non-interactive update 'curl'",
      exitCode = 0,
      stdout = "Updating: curl\n",
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
