return {
  name = "vpm remove installed package",
  request = {
    action = "remove",
    system = "vpm",
    packages = {
      { name = "nedpals.args" }
    },
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' VMODULES='/home/test/.vmodules' /usr/local/bin/v remove nedpals.args",
      exitCode = 0,
      stdout = "Removing module \"nedpals.args\" ...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
