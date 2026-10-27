return {
  name = "sbt outdated empty",
  fixtureRoot = "/tmp/opencode/sbt-outdated-case",
  request = {
    action = "outdated",
    system = "sbt",
  },
  fakeExec = {
    {
      match = "command -v sbt >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
