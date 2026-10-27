return {
  name = "pacman list",
  request = {
    action = "list",
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
      match = "LC_ALL=C pacman -Q",
      exitCode = 0,
      stdout = "curl 8.8.0-1\nripgrep 14.1.1-1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "curl",
    resultVersion = "8.8.0-1",
  }
}
