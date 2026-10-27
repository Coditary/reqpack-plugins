return {
  name = "clasp installLocal pushes project",
  fixtureRoot = "/tmp/opencode/clasp-install-local-case",
  request = {
    action = "install",
    system = "clasp",
    localPath = "/tmp/opencode/clasp-install-local-case/project",
    flags = { "force" },
  },
  fixtureDirs = {
    "project",
  },
  fakeExec = {
    {
      match = "cd '/tmp/opencode/clasp-install-local-case/project' && clasp push",
      exitCode = 0,
      stdout = "Pushed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
