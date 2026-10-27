return {
  name = "snap outdated packages",
  request = {
    action = "outdated",
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
      match = "snap refresh --list",
      exitCode = 0,
      stdout = "Name      Version    Rev   Size   Publisher  Notes\nfirefox   125.0-2    4900  257MB  mozilla✓   -\n",
      stderr = "",
      success = true,
    },
    {
      match = "snap list",
      exitCode = 0,
      stdout = "Name      Version    Rev   Tracking       Publisher  Notes\nfirefox   124.0-1    4800  latest/stable  mozilla✓   -\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "firefox",
    resultVersion = "124.0-1",
  }
}
