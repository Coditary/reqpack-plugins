return {
  name = "pacman outdated",
  request = {
    action = "outdated",
    system = "pacman",
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
      match = "LC_ALL=C pacman -Qu",
      exitCode = 0,
      stdout = "curl 8.7.1-1 -> 8.8.0-1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.7.1-1",
  }
}
