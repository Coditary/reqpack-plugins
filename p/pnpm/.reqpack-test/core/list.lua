return {
  name = "pnpm list direct project dependencies",
  request = {
    action = "list",
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
      match = "pnpm list --json --depth 0",
      exitCode = 0,
      stdout = [=[[
  {
    "name": "demo",
    "version": "1.0.0",
    "path": "/workspace/demo",
    "private": false,
    "dependencies": {
      "is-number": {
        "from": "is-number",
        "version": "7.0.0",
        "resolved": "https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz",
        "path": "/workspace/demo/node_modules/.pnpm/is-number@7.0.0/node_modules/is-number"
      }
    },
    "devDependencies": {
      "@types/is-number": {
        "from": "@types/is-number",
        "version": "7.0.5",
        "resolved": "https://registry.npmjs.org/@types/is-number/-/is-number-7.0.5.tgz",
        "path": "/workspace/demo/node_modules/.pnpm/@types+is-number@7.0.5/node_modules/@types/is-number"
      }
    },
    "optionalDependencies": {
      "once": {
        "from": "once",
        "version": "1.4.0",
        "resolved": "https://registry.npmjs.org/once/-/once-1.4.0.tgz",
        "path": "/workspace/demo/node_modules/.pnpm/once@1.4.0/node_modules/once"
      }
    }
  }
]
]=],
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
      "pnpm list --json --depth 0",
      "pnpm store path",
    },
    resultCount = 3,
    resultName = "@types/is-number",
    resultVersion = "7.0.5",
    events = { "listed" },
  },
}
