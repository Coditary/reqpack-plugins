return {
  name = "vpm info merged remote and local",
  request = {
    action = "info",
    system = "vpm",
    prompt = "nedpals.args",
  },
  fixtureDirs = {
    "/home/test/.vmodules",
    "/home/test/.vmodules/nedpals",
    "/home/test/.vmodules/nedpals/args",
    "/home/test/.vmodules/nedpals/args/.git",
  },
  fixtureFiles = {
    {
      path = "/home/test/.vmodules/nedpals/args/v.mod",
      content = [[
Module {
  name: 'nedpals.args'
  version: '0.10.0'
  description: 'Simple CLI args parser'
  license: 'MIT'
  repo_url: 'https://github.com/nedpals/args'
}
]],
    },
  },
  environment = {},
  fakeExec = {
    {
      match = "cat '/home/test/.vmodules/nedpals/args/v.mod'",
      exitCode = 0,
      stdout = "Module {\n  name: 'nedpals.args'\n  version: '0.10.0'\n  description: 'Simple CLI args parser'\n  license: 'MIT'\n  repo_url: 'https://github.com/nedpals/args'\n}\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.vmodules'",
      exitCode = 0,
      stdout = "nedpals\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.vmodules/nedpals'",
      exitCode = 0,
      stdout = "args\n",
      stderr = "",
      success = true,
    },
    {
      match = "ls -1A '/home/test/.vmodules/nedpals/args'",
      exitCode = 0,
      stdout = ".git\nv.mod\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v v 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/local/bin/v\n",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' VMODULES='/home/test/.vmodules' /usr/local/bin/v show nedpals.args",
      exitCode = 0,
      stdout = "Name: nedpals.args\nHomepage: https://github.com/nedpals/args\nDownloads: 1200\nInstalled: true\nVersion: 0.11.0\nDescription: Simple CLI args parser\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "nedpals.args",
    resultVersion = "0.10.0",
  }
}
