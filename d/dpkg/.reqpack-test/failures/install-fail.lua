return {
  name = "dpkg install failure",
  request = {
    action = "install",
    system = "dpkg",
    packages = {
      { name = "delta", version = "1.0.0" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'dpkg' >/dev/null 2>&1 && command -v 'dpkg-query' >/dev/null 2>&1 && command -v 'apt-cache' >/dev/null 2>&1 && command -v 'apt-get' >/dev/null 2>&1 && command -v 'apt' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "apt-get install -y -- 'delta=1.0.0'",
      exitCode = 100,
      stdout = "",
      stderr = "broken\n",
      success = false,
    },
  },
  expect = {
    success = false,
    commands = { "apt-get install -y -- 'delta=1.0.0'" },
    stderr = { "broken\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "dpkg install failed",
    },
  }
}
