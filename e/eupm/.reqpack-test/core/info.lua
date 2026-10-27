return {
  name = "eupm info package",
  request = {
    action = "info",
    system = "eupm",
    prompt = "sequence-utils",
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
      match = "eupm info 'sequence-utils'",
      exitCode = 0,
      stdout = "Name: sequence-utils\nVersion: 1.2.0\nSummary: Sequence helpers for Euphoria\nDescription: Utility routines for sequence processing\nHomepage: https://example.test/sequence-utils\nLicense: MIT\nStatus: installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "eupm info 'sequence-utils'",
    },
    events = { "informed" },
    resultName = "sequence-utils",
    resultVersion = "1.2.0",
  }
}
