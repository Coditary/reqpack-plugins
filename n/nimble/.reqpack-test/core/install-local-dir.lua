return {
  name = "nimble install local directory",
  request = {
    action = "install",
    system = "nimble",
    localPath = "${fixtureRoot}/samplepkg",
  },
  fixtureDirs = {
    "samplepkg",
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
      match = "test -d '${fixtureRoot}/samplepkg'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -f '${fixtureRoot}/samplepkg'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "nimble --accept --noColor install '${fixtureRoot}/samplepkg'",
      exitCode = 0,
      stdout = "Success: samplepkg installed successfully.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "test -d '${fixtureRoot}/samplepkg'",
      "test -f '${fixtureRoot}/samplepkg'",
      "nimble --accept --noColor install '${fixtureRoot}/samplepkg'"
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=${fixtureRoot}/samplepkg}",
      success = "ok",
    },
  }
}
