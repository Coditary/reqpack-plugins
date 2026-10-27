return {
  name = "zypper install",
  request = {
    action = "install",
    system = "zypper",
    packages = {
      { name = "curl", version = "8.9.1" }
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
      match = "zypper --non-interactive install 'curl-8.9.1'",
      exitCode = 0,
      stdout = "Installing: curl-8.9.1\n",
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
