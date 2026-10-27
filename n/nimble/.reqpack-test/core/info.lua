return {
  name = "nimble info installed",
  request = {
    action = "info",
    system = "nimble",
    prompt = "jester",
  },
  fakeExec = {
    {
      match = "command -v nimble >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --noColor list -i",
      exitCode = 0,
      stdout = "jester  [0.6.0]\n",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --noColor path 'jester'",
      exitCode = 0,
      stdout = "/home/test/.nimble/pkgs2/jester-0.6.0-aaaaaaaa\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "nimble --noColor list -i",
      "nimble --noColor path 'jester'"
    },
    events = { "informed" },
    resultCount = 1,
    resultName = "jester",
    resultVersion = "0.6.0",
  }
}
