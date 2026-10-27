return {
  name = "pinokio remove app",
  request = {
    action = "remove",
    system = "pinokio",
    packages = { { name = "app:pinokio" } },
  },
  fixtureRoot = "../fixtures-remove-app",
  fixtureDirs = {
    "home/pinokio/reqpack",
    "home/pinokio/app",
    "home/pinokio/api/demo",
  },
  fixtureFiles = {
    { path = "home/pinokio/reqpack/app.json", content = [[{"version":"7.1.12"}]] },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '", exitCode = 0, stdout = "", stderr = "", success = true },
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
