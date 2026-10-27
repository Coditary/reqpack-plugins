return {
  name = "haxelib update package",
  request = {
    action = "update",
    system = "haxelib",
    packages = {
      { name = "lime" }
    },
  },
  fakeExec = {
    {
      match = "haxelib --quiet --global --always update 'lime'",
      exitCode = 0,
      stdout = "Updating lime...\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "haxelib --quiet --global --always update 'lime'",
    },
    events = { "updated", "success" },
  },
}
