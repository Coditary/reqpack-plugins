return {
  name = "ocx installLocal unsupported",
  request = {
    action = "installLocal",
    system = "ocx",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    localPath = "${fixtureRoot}/bundle.tar.gz",
  },
  fixtureRoot = "/tmp/opencode/ocx-install-local",
  fixtureDirs = {
    "project",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed" },
    resultCount = 0,
    eventPayloads = {
      failed = "ocx installLocal is not supported",
    },
  },
}
