return {
  name = "pnpm list direct global dependencies",
  request = {
    action = "list",
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
      match = "pnpm list --json --depth 0 --global",
      exitCode = 0,
      stdout = [=[[
  {
    "path": "/home/test/.local/share/pnpm/global/5",
    "private": false,
    "dependencies": {
      "cowsay": {
        "from": "cowsay",
        "version": "1.6.0",
        "resolved": "https://registry.npmjs.org/cowsay/-/cowsay-1.6.0.tgz",
        "path": "/home/test/.local/share/pnpm/global/5/.pnpm/cowsay@1.6.0/node_modules/cowsay"
      }
    }
  }
]
]=],
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
    resultVersion = "1.6.0",
    events = { "listed" },
  },
}
