return {
  name = "pinokio list",
  request = {
    action = "list",
    system = "pinokio",
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "home/pinokio/reqpack",
    "home/pinokio/api/foo",
  },
  fixtureFiles = {
    { path = "home/pinokio/reqpack/app.json", content = [[{"version":"7.1.12","install_root":"${fixtureRoot}/home/pinokio/app/Pinokio.AppImage"}]] },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -d '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "find '", exitCode = 0, stdout = "${fixtureRoot}/home/pinokio/api/foo\n", stderr = "", success = true },
    { match = "remote get-url origin", exitCode = 0, stdout = "https://github.com/pinokiocomputer/foo.git\n", stderr = "", success = true },
    { match = "rev-parse --short HEAD", exitCode = 0, stdout = "abc123\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "app:pinokio",
    resultVersion = "7.1.12",
  }
}
