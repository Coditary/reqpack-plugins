return {
  name = "vpm list installed modules",
  request = {
    action = "list",
    system = "vpm",
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
  dependencies: ['v.url']
}
]],
    },
  },
  environment = {},
  fakeExec = {
    {
      match = "cat '/home/test/.vmodules/nedpals/args/v.mod'",
      exitCode = 0,
      stdout = "Module {\n  name: 'nedpals.args'\n  version: '0.10.0'\n  description: 'Simple CLI args parser'\n  license: 'MIT'\n  repo_url: 'https://github.com/nedpals/args'\n  dependencies: ['v.url']\n}\n",
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
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "nedpals.args",
    resultVersion = "0.10.0",
  }
}
