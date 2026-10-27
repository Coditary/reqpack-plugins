return {
  name = "dpkg install",
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
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "apt-get install -y -- 'delta=1.0.0'" },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
