return {
  name = "pinokio update script repo",
  request = {
    action = "update",
    system = "pinokio",
    packages = { { name = "script:pinokiocomputer/foo" } },
  },
  fixtureRoot = "../fixtures-update-script",
  fixtureDirs = {
    "home/pinokio/api/foo",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "git -C '", exitCode = 0, stdout = "Updating\n", stderr = "", success = true },
    { match = "remote get-url origin", exitCode = 0, stdout = "https://github.com/pinokiocomputer/foo.git\n", stderr = "", success = true },
    { match = "rev-parse --short HEAD", exitCode = 0, stdout = "def456\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
