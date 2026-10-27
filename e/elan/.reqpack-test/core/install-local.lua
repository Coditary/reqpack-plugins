return {
  name = "elan link local toolchain",
  request = {
    action = "installLocal",
    system = "elan",
    localPath = "/tmp/lean-dev",
    packages = {
      { name = "lean-dev", action = "installLocal" }
    },
  },
  fakeExec = {
    {
      match = "command -v elan >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "elan toolchain link 'lean-dev' '/tmp/lean-dev'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "elan toolchain link 'lean-dev' '/tmp/lean-dev'",
    },
    events = { "installed", "success" },
  }
}
