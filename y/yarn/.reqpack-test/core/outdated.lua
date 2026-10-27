return {
  name = "yarn outdated global packages",
  request = {
    action = "outdated",
    system = "yarn",
  },
  fakeExec = {
    {
      match = "command -v yarn >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "yarn --version",
      exitCode = 0,
      stdout = "1.22.22\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn global dir",
      exitCode = 0,
      stdout = "/home/test/.config/yarn/global\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn global bin",
      exitCode = 0,
      stdout = "/home/test/.yarn/bin\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn cache dir",
      exitCode = 0,
      stdout = "/home/test/.cache/yarn/v6\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn --cwd /home/test/.config/yarn/global outdated --json",
      exitCode = 1,
      stdout = [=[{"type":"table","data":{"head":["Package","Current","Wanted","Latest","Package Type","URL"],"body":[["eslint","9.1.0","9.1.0","9.2.0","dependencies","https://eslint.org"]]}}]=],
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "eslint",
    resultVersion = "9.1.0",
  }
}
