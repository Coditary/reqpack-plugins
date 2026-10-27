return {
  name = "yarn remove global package",
  request = {
    action = "remove",
    system = "yarn",
    packages = {
      { name = "eslint" }
    },
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
      match = "yarn global remove eslint --non-interactive --silent --no-progress",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v yarn >/dev/null 2>&1",
      "yarn --version",
      "yarn global dir",
      "yarn global bin",
      "yarn cache dir",
      "yarn global remove eslint --non-interactive --silent --no-progress"
    },
    events = { "deleted", "success" },
  }
}
