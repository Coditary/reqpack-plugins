return {
  name = "dpkg update",
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
      exitCode = 0,
      stdout = "updated\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "apt-get install --only-upgrade -y -- 'delta'" },
    stdout = { "updated\n" },
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
