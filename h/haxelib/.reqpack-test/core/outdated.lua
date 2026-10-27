return {
  name = "haxelib outdated package",
  request = {
    action = "outdated",
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
      stdout = "lime: [8.1.2]\nformat: [3.7.0]\n",
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
    {
      match = "haxelib --quiet --global libpath 'format'",
      exitCode = 0,
      stdout = "/home/test/haxelib/format/3,7,0/\n",
      stderr = "",
      success = true,
    },
    {
      match = "haxelib --quiet info 'lime'",
      exitCode = 0,
      stdout = "Cross-platform library for Haxe projects.\n\nVersion: 8.1.3\nRecent releases:\n  8.1.3 (2026-05-01)\n  8.1.2 (2025-10-10)\n",
      stderr = "",
      success = true,
    },
    {
      match = "haxelib --quiet info 'format'",
      exitCode = 0,
      stdout = "Input/output format helpers.\n\nVersion: 3.7.0\nRecent releases:\n  3.7.0 (2026-04-01)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed", "outdated" },
    resultCount = 1,
    resultName = "lime",
    resultVersion = "8.1.2",
  },
}
