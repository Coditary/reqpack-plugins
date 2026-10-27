return {
  name = "nimble install local nimble file",
  request = {
    action = "install",
    system = "nimble",
    localPath = "${fixtureRoot}/demo/demo.nimble",
  },
  fixtureDirs = {
    "demo",
  },
  fixtureFiles = {
    {
      path = "demo/demo.nimble",
      content = "version = \"0.1.0\"\n",
    },
  },
  fakeExec = {
    {
      match = "command -v nimble >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '${fixtureRoot}/demo/demo.nimble'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "test -f '${fixtureRoot}/demo/demo.nimble'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "nimble --accept --noColor install '${fixtureRoot}/demo/demo.nimble'",
      exitCode = 0,
      stdout = "Success: demo installed successfully.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "test -d '${fixtureRoot}/demo/demo.nimble'",
      "test -f '${fixtureRoot}/demo/demo.nimble'",
      "nimble --accept --noColor install '${fixtureRoot}/demo/demo.nimble'"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=${fixtureRoot}/demo/demo.nimble}",
      success = "ok",
    },
  }
}
