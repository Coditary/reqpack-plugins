return {
  name = "dpkg install local",
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
      exitCode = 0,
      stdout = "installed local\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "dpkg -i -- '/tmp/delta.deb'" },
    stdout = { "installed local\n" },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
