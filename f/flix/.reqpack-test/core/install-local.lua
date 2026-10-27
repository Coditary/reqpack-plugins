return {
  name = "flix install local project",
  fixtureRoot = "/tmp/opencode/flix-install-local-case",
  request = {
    action = "install",
    system = "flix",
    localPath = "/tmp/opencode/flix-install-local-case/local-project",
  },
  fixtureDirs = {
    "local-project",
  },
  fakeExec = {
    {
      match = "command -v flix >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/tmp/opencode/flix-install-local-case/local-project' && flix build-pkg",
      exitCode = 0,
      stdout = "built\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "cd '/tmp/opencode/flix-install-local-case/local-project' && flix build-pkg"
    },
    events = { "installed", "success" },
  }
}
