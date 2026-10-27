return {
  name = "pnpm outdated global dependencies",
  request = {
    action = "outdated",
    system = "pnpm",
    flags = { "global" },
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
      match = "pnpm outdated --format json --global",
      exitCode = 0,
      stdout = [=[{
  "cowsay": {
    "current": "1.5.0",
    "latest": "1.6.0",
    "wanted": "1.5.0",
    "isDeprecated": false,
    "dependencyType": "global"
  }
}]=],
      stderr = "",
      success = true,
    },
    {
      match = "pnpm store path --global",
      exitCode = 0,
      stdout = "/home/test/.local/share/pnpm/store/v10\n",
      stderr = "",
      success = true,
    },
    {
      match = "pnpm root --global",
      exitCode = 0,
      stdout = "/home/test/.local/share/pnpm/global/5/node_modules\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "cowsay",
    resultVersion = "1.5.0",
    events = { "outdated" },
  },
}
