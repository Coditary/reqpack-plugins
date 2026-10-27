return {
  name = "dpkg install local failure",
  request = {
    action = "install",
    system = "dpkg",
    localPath = "/tmp/delta.deb",
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
      match = "dpkg -i -- '/tmp/delta.deb'",
      exitCode = 1,
      stdout = "",
      stderr = "bad deb\n",
      success = false,
    },
  },
  expect = {
    success = false,
    commands = { "dpkg -i -- '/tmp/delta.deb'" },
    stderr = { "bad deb\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "local dpkg install failed",
    },
  }
}
