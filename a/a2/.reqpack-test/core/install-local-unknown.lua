return {
  name = "a2 install local unknown source fails",
  request = {
    action = "installLocal",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    localPath = "${fixtureRoot}/mystery-dir",
  },
  fakeExec = {
    { match = "test -d 'mystery-dir'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  fixtureDirs = {
    "${fixtureRoot}/mystery-dir",
  },
  expect = {
    success = false,
    events = { "failed" },
  }
}
