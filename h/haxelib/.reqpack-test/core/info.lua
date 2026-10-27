return {
  name = "haxelib info installed package",
  request = {
    action = "info",
    system = "haxelib",
    prompt = "lime",
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
      stdout = "Cross-platform library for Haxe projects.\n\nVersion: 8.1.3\nLicense: MIT\nWebsite: https://lime.openfl.org\nOwner: openfl\nTags: haxe, graphics\nDependencies:\n  format\nRecent releases:\n  8.1.3 (2026-05-01)\n  8.1.2 (2025-10-10)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "lime",
    resultVersion = "8.1.2",
    eventPayloads = {
      informed = "{dependencies=<lua-value>, description=Cross-platform library for Haxe projects., extraFields=<lua-value>, homepage=https://lime.openfl.org, installed=true, latestVersion=8.1.3, license=MIT, name=lime, packageId=lime, packageType=library, repository=lib.haxe.org, status=outdated, summary=Cross-platform library for Haxe projects., type=package, version=8.1.2}",
    },
  },
}
