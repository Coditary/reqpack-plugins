return {
  name = "vpm outdated modules",
  request = {
    action = "outdated",
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
}
]],
    },
  },
  environment = {},
  fakeExec = {
    {
      match = "command -v v 2>/dev/null",
      exitCode = 0,
      stdout = "/usr/local/bin/v\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.vmodules/nedpals/args/v.mod'",
      exitCode = 0,
      stdout = "Module {\n  name: 'nedpals.args'\n  version: '0.10.0'\n  description: 'Simple CLI args parser'\n}\n",
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' VMODULES='/home/test/.vmodules' /usr/local/bin/v outdated",
      exitCode = 0,
      stdout = "Outdated modules:\nnedpals.args\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "nedpals.args",
    resultVersion = "0.10.0",
  }
}
