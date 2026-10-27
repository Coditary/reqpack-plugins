return {
  name = "pnpm outdated project dependencies",
  request = {
    action = "outdated",
    system = "pnpm",
  },
  fakeExec = {
    {
      match = "command -v 'pnpm' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "pnpm outdated --format json",
      exitCode = 0,
      stdout = [=[{
  "chalk": {
    "current": "5.3.0",
    "latest": "5.6.2",
    "wanted": "5.3.0",
    "isDeprecated": false,
    "dependencyType": "dependencies"
  }
}]=],
      stderr = "",
      success = true,
    },
    {
      match = "pnpm store path",
      exitCode = 0,
      stdout = "/home/test/.local/share/pnpm/store/v10\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "pnpm outdated --format json",
      "pnpm store path",
    },
    resultCount = 1,
    resultName = "chalk",
    resultVersion = "5.3.0",
    events = { "outdated" },
  },
}
