return {
  name = "haxelib install local zip",
  request = {
    action = "install",
    system = "haxelib",
    localPath = "/tmp/test/demo.zip",
  },
  fakeExec = {
    {
      match = "haxelib --quiet --global --always install '/tmp/test/demo.zip'",
      exitCode = 0,
      stdout = "Installing demo.zip...\nDone\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "haxelib --quiet --global --always install '/tmp/test/demo.zip'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/test/demo.zip}",
      success = "ok",
    },
  },
}
