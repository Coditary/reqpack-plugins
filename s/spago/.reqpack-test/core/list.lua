return {
  name = "spago list workspace dependencies",
  request = {
    action = "list",
    system = "spago",
  },
  fakeExec = {
    {
      match = "command -v 'spago' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spago ls paths --json",
      exitCode = 0,
      stdout = [[{"Global cache path":"/home/test/.cache/spago-nodejs","Global registry path":"/home/test/.cache/spago-nodejs/registry","Local cache path":"/workspace/.spago","Local cache packages path":"/workspace/.spago/packages"}]],
      stderr = "",
      success = true,
    },
    {
      match = "spago ls deps --json --transitive",
      exitCode = 0,
      stdout = [[{"effect":{"type":"registry","value":{"version":"4.0.0"}},"prelude":{"type":"registry","value":{"version":"6.0.2"}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'spago' >/dev/null 2>&1",
      "spago ls paths --json",
      "spago ls deps --json --transitive",
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "effect",
    resultVersion = "4.0.0",
  }
}
