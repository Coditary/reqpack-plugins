return {
  name = "vpm search remote packages",
  request = {
    action = "search",
    system = "vpm",
    prompt = "args",
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
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' VMODULES='/home/test/.vmodules' /usr/local/bin/v search args",
      exitCode = 0,
      stdout = "nedpals.args\nvlang.cli\n",
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
    {
      match = "NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' VMODULES='/home/test/.vmodules' /usr/local/bin/v show vlang.cli",
      exitCode = 0,
      stdout = "Name: vlang.cli\nHomepage: https://github.com/vlang/cli\nDownloads: 999\nInstalled: false\nVersion: 1.2.0\nDescription: Command line helpers\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "nedpals.args",
    resultVersion = "0.10.0",
  }
}
