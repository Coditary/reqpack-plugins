return {
  name = "dpkg update failure",
  request = {
    action = "update",
    system = "dpkg",
    packages = {
      { name = "delta" }
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
      match = "apt-get install --only-upgrade -y -- 'delta'",
      exitCode = 100,
      stdout = "",
      stderr = "update failed\n",
      success = false,
    },
  },
  expect = {
    success = false,
    commands = { "apt-get install --only-upgrade -y -- 'delta'" },
    stderr = { "update failed\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "dpkg update failed",
    },
  }
}
