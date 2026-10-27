return {
  name = "yarn search npm registry",
  request = {
    action = "search",
    system = "yarn",
    prompt = "eslint",
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
      match = "curl -fsSL 'https://registry.npmjs.org/-/v1/search?text=eslint&size=20'",
      exitCode = 0,
      stdout = [[{"objects":[{"package":{"name":"eslint","version":"9.2.0","description":"AST-based pattern checker","links":{"homepage":"https://eslint.org","repository":"https://github.com/eslint/eslint","npm":"https://www.npmjs.com/package/eslint"},"keywords":["javascript","lint"]},"score":{"final":0.98}}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "eslint",
    resultVersion = "9.2.0",
  }
}
