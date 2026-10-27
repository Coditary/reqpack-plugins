return {
  name = "yarn list global packages",
  request = {
    action = "list",
    system = "yarn",
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "home/.config/yarn/global",
  },
  fixtureFiles = {
    {
      path = "home/.config/yarn/global/package.json",
      content = [[{"dependencies":{"eslint":"^9.1.0","typescript":"^5.8.0"}}]],
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
      stdout = [[{"type":"info","data":"\"eslint@9.1.0\" has binaries: eslint"}
{"type":"info","data":"\"typescript@5.8.2\" has binaries: tsc tsserver"}
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "eslint",
    resultVersion = "9.1.0",
  }
}
