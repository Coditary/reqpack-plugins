return {
  name = "pinokio info script",
  request = {
    action = "info",
    system = "pinokio",
    prompt = "script:pinokiocomputer/foo",
  },
  fixtureRoot = "../fixtures-info-script",
  fixtureDirs = {
    "home/pinokio/api/foo",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "remote get-url origin", exitCode = 0, stdout = "https://github.com/pinokiocomputer/foo.git\n", stderr = "", success = true },
    { match = "rev-parse --short HEAD", exitCode = 0, stdout = "abc123\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "script:pinokiocomputer/foo",
    resultVersion = "abc123",
  }
}
