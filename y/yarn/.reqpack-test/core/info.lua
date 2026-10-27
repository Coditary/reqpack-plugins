return {
  name = "yarn info with installed overlay",
  request = {
    action = "info",
    system = "yarn",
    prompt = "eslint",
  },
  fixtureRoot = "../fixtures-info",
  fixtureDirs = {
    "home/.config/yarn/global",
  },
  fixtureFiles = {
    {
      path = "home/.config/yarn/global/package.json",
      content = [[{"dependencies":{"eslint":"^9.1.0"}}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
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
      stdout = "${fixtureRoot}/home/.config/yarn/global\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn global bin",
      exitCode = 0,
      stdout = "${fixtureRoot}/home/.yarn/bin\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn cache dir",
      exitCode = 0,
      stdout = "${fixtureRoot}/home/.cache/yarn/v6\n",
      stderr = "",
      success = true,
    },
    {
      match = "yarn global list --depth=0 --json",
      exitCode = 0,
      stdout = [[{"type":"info","data":"\"eslint@9.1.0\" has binaries: eslint"}]],
      stderr = "",
      success = true,
    },
    {
      match = "yarn info eslint --json",
      exitCode = 0,
      stdout = [[{"type":"inspect","data":{"name":"eslint","version":"9.1.0","description":"AST-based pattern checker","license":"MIT","homepage":"https://eslint.org","repository":{"url":"git+https://github.com/eslint/eslint.git"},"dist-tags":{"latest":"9.2.0"},"time":{"created":"2013-06-14T00:00:00.000Z","modified":"2026-05-28T00:00:00.000Z"}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "eslint",
    resultVersion = "9.1.0",
  }
}
