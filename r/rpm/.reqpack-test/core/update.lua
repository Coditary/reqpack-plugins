return {
  name = "rpm update without repo helper fails",
  request = {
    action = "update",
    system = "rpm",
    packages = {
      { name = "curl" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'rpm' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'dnf' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "command -v 'yum' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    }
  },
  expect = {
    success = false,
    commands = {
      "command -v 'dnf' >/dev/null 2>&1",
      "command -v 'yum' >/dev/null 2>&1"
    },
    events = { "failed" },
    eventPayloads = {
      failed = "repo update requires dnf or yum",
    },
  }
}
