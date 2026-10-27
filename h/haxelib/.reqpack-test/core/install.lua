return {
  name = "haxelib install latest",
  request = {
    action = "install",
    system = "haxelib",
    packages = {
      { name = "lime" }
    },
  },
  fakeExec = {
    {
      match = "haxelib --quiet --global --always install 'lime'",
      exitCode = 0,
      stdout = "Installing lime...\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "haxelib --quiet --global --always install 'lime'",
    },
    events = { "installed", "success" },
  },
}
