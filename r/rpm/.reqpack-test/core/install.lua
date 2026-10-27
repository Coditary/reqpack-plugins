return {
  name = "rpm install via dnf",
  request = {
    action = "install",
    system = "rpm",
    packages = {
      { name = "curl", version = "8.0.1" }
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
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "dnf install -y 'curl-8.0.1'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    commands = {
      "command -v 'dnf' >/dev/null 2>&1",
      "dnf install -y 'curl-8.0.1'"
    },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "<lua-value>",
      success = "ok",
    },
  }
}
