return {
  name = "nimble list installed",
  request = {
    action = "list",
    system = "nimble",
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
      stdout = "jester  [0.6.0]\nc4  [#head]\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "nimble --noColor list -i"
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "c4",
    resultVersion = "#head",
  }
}
