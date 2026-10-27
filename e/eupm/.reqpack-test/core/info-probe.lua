return {
  name = "eupm probe remaps info verb",
  request = {
    action = "info",
    system = "eupm",
    prompt = "sequence-utils",
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
      match = "eupm show 'sequence-utils'",
      exitCode = 0,
      stdout = "Name: sequence-utils\nVersion: 1.2.0\nSummary: Sequence helpers for Euphoria\n",
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
      "eupm show 'sequence-utils'",
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "sequence-utils",
    resultVersion = "1.2.0",
  }
}
