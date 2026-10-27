return {
  name = "dpkg outdated",
  request = {
    action = "outdated",
    system = "dpkg",
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
      match = "apt list --upgradable 2>/dev/null",
      exitCode = 0,
      stdout = "Listing...\ndelta/stable 1.1.0 amd64 [upgradable from: 1.0.0]\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "delta",
    resultVersion = "1.0.0",
  }
}
