return {
  name = "haxelib list installed packages",
  request = {
    action = "list",
    system = "haxelib",
  },
  fakeExec = {
    {
      match = "haxelib --quiet --global config",
      exitCode = 0,
      stdout = "/home/test/haxelib\n",
      stderr = "",
      success = true,
    },
    {
      match = "haxelib --quiet --global list",
      exitCode = 0,
      stdout = "format: [3.7.0] 3.6.0\nlime: [8.1.2]\n",
      stderr = "",
      success = true,
    },
    {
      match = "haxelib --quiet --global libpath 'format'",
      exitCode = 0,
      stdout = "/home/test/haxelib/format/3,7,0/\n",
      stderr = "",
      success = true,
    },
    {
      match = "haxelib --quiet --global libpath 'lime'",
      exitCode = 0,
      stdout = "/home/test/haxelib/lime/8,1,2/\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "haxelib --quiet --global config",
      "haxelib --quiet --global list",
      "haxelib --quiet --global libpath 'format'",
      "haxelib --quiet --global libpath 'lime'",
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "format",
    resultVersion = "3.7.0",
  },
}
