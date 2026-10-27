return {
  name = "eupm search packages",
  request = {
    action = "search",
    system = "eupm",
    prompt = "sequence",
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
      match = "eupm search 'sequence'",
      exitCode = 0,
      stdout = "sequence-utils 1.2.0 - Sequence helpers for Euphoria\nsequence-extra 0.4.0 - Extra sequence algorithms\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm search 'sequence'",
    },
    events = { "searched" },
    resultCount = 2,
    resultName = "sequence-utils",
    resultVersion = "1.2.0",
  }
}
