return {
  name = "haxelib remove package",
  request = {
    action = "remove",
    system = "haxelib",
    packages = {
      { name = "lime", version = "8.1.2" }
    },
  },
  fakeExec = {
    {
      match = "haxelib --quiet --global remove 'lime' '8.1.2'",
      exitCode = 0,
      stdout = "Removing lime 8.1.2...\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "haxelib --quiet --global remove 'lime' '8.1.2'",
    },
    events = { "deleted", "success" },
  },
}
