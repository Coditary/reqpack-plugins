return {
  name = "conan outdated empty",
  request = {
    action = "outdated",
    system = "conan",
  },
  fakeExec = {
    {
      match = "command -v 'conan' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'conan' >/dev/null 2>&1"
    },
    events = { "outdated" },
    resultCount = 0,
  }
}
