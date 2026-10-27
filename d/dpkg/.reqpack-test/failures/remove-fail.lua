return {
  name = "dpkg remove failure",
  request = {
    action = "remove",
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
      match = "dpkg -r -- 'delta'",
      exitCode = 1,
      stdout = "",
      stderr = "remove failed\n",
      success = false,
    },
  },
  expect = {
    success = false,
    commands = { "dpkg -r -- 'delta'" },
    stderr = { "remove failed\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "dpkg remove failed",
    },
  }
}
