return {
  name = "pinokio remove script repo",
  request = {
    action = "remove",
    system = "pinokio",
    packages = { { name = "script:pinokiocomputer/foo" } },
  },
  fixtureRoot = "../fixtures-remove-script",
  fixtureDirs = {
    "home/pinokio/api/foo",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "remote get-url origin", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "rev-parse --short HEAD", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
