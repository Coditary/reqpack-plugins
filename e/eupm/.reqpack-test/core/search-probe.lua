return {
  name = "eupm probe remaps search verb",
  request = {
    action = "search",
    system = "eupm",
    prompt = "sequence",
    flags = { "probe" },
  },
  fakeExec = {
    {
      match = "command -v eupm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "eupm --help",
      exitCode = 0,
      stdout = "Commands: install uninstall upgrade installed find show\n",
      stderr = "",
      success = true,
    },
    {
      match = "eupm help",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "eupm -h",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "eupm find 'sequence'",
      exitCode = 0,
      stdout = "sequence-utils 1.2.0 - Sequence helpers for Euphoria\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v eupm >/dev/null 2>&1",
      "eupm --help",
      "eupm help",
      "eupm -h",
      "eupm find 'sequence'",
    },
    events = { "searched" },
    resultCount = 1,
    resultName = "sequence-utils",
    resultVersion = "1.2.0",
  }
}
