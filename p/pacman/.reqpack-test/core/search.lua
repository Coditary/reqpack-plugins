return {
  name = "pacman search",
  request = {
    action = "search",
    system = "pacman",
    prompt = "curl",
  },
  fakeExec = {
    {
      match = "command -v pacman >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "LC_ALL=C pacman -Ss curl",
      exitCode = 0,
      stdout = "extra/curl 8.8.0-1\n    command line tool and library for transferring data with URLs\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.8.0-1",
  }
}
