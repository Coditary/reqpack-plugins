return {
  name = "pnpm search npm registry",
  request = {
    action = "search",
    system = "pnpm",
    prompt = "is-number",
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
      match = "pnpm search 'is-number' --json",
      exitCode = 0,
      stdout = [=[[
  {
    "name": "is-number",
    "version": "7.0.0",
    "description": "Returns true if a number or string value is a finite number.",
    "license": "MIT",
    "date": "2018-07-04T15:08:58.238Z",
    "links": {
      "homepage": "https://github.com/jonschlinkert/is-number",
      "repository": "git+https://github.com/jonschlinkert/is-number.git",
      "npm": "https://www.npmjs.com/package/is-number"
    },
    "publisher": {
      "username": "jonschlinkert"
    }
  }
]
]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "pnpm search 'is-number' --json",
    },
    resultCount = 1,
    resultName = "is-number",
    resultVersion = "7.0.0",
    events = { "searched" },
  },
}
