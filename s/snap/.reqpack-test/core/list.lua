return {
  name = "snap list installed",
  request = {
    action = "list",
    system = "snap",
  },
  fakeExec = {
    {
      match = "command -v 'snap' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "snap list",
      exitCode = 0,
      stdout = "Name         Version    Rev   Tracking       Publisher   Notes\nfirefox      124.0-1    4800  latest/stable  mozilla✓    -\nhello-world  6.4        29    latest/stable  canonical✓  -\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "firefox",
    resultVersion = "124.0-1",
  }
}
