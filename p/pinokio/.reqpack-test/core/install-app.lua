return {
  name = "pinokio install app",
  request = {
    action = "install",
    system = "pinokio",
    packages = {
      {
        name = "app:pinokio",
        version = "7.1.12",
        sourcePath = "file://${fixtureRoot}/assets/Pinokio-7.1.12.AppImage"
      }
    },
  },
  fixtureRoot = "../fixtures-install-app",
  fixtureDirs = {
    "assets",
    "home/pinokio/reqpack",
    "home/pinokio/app",
  },
  fixtureFiles = {
    {
      path = "assets/Pinokio-7.1.12.AppImage",
      content = "appimage",
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -d '", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "chmod +x '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-28T12:00:00Z\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
