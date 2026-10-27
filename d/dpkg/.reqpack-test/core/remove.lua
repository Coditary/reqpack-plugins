return {
  name = "dpkg remove",
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
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "dpkg -r -- 'delta'" },
    stdout = { "removed\n" },
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
