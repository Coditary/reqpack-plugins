return {
  name = "yarn update global package",
  request = {
    action = "update",
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
      match = "yarn global upgrade eslint --latest --non-interactive --silent --no-progress",
      exitCode = 0,
      stdout = "updated\n",
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
      "yarn global upgrade eslint --latest --non-interactive --silent --no-progress"
    },
    events = { "updated", "success" },
  }
}
