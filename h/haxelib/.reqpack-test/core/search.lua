return {
  name = "haxelib search enriches info",
  request = {
    action = "search",
    system = "haxelib",
    prompt = "lime",
  },
  fakeExec = {
    {
      match = "haxelib --quiet search 'lime'",
      exitCode = 0,
      stdout = "lime\nlime-tools\n",
      stderr = "",
      success = true,
    },
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
      stdout = "lime: [8.1.2]\n",
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
      match = "haxelib --quiet info 'lime'",
      exitCode = 0,
      stdout = "Cross-platform library for Haxe projects.\n\nVersion: 8.1.3\nLicense: MIT\nWebsite: https://lime.openfl.org\nTags: haxe, cross-platform\nRecent releases:\n  8.1.3 (2026-05-01)\n  8.1.2 (2025-10-10)\n",
      stderr = "",
      success = true,
    },
    {
      match = "haxelib --quiet info 'lime-tools'",
      exitCode = 0,
      stdout = "Tooling package for Lime.\n\nVersion: 1.0.0\nLicense: MIT\nWebsite: https://example.com/lime-tools\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "lime",
    resultVersion = "8.1.2",
  },
}
