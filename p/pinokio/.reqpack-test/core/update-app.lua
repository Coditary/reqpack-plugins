return {
  name = "pinokio update app",
  request = {
    action = "update",
    system = "pinokio",
    packages = {
      {
        name = "app:pinokio",
        version = "7.2.6",
        sourcePath = "file://${fixtureRoot}/assets/Pinokio-7.2.6.AppImage"
      }
    },
  },
  fixtureRoot = "../fixtures-update-app",
  fixtureDirs = {
    "assets",
    "home/pinokio/reqpack",
    "home/pinokio/app",
  },
  fixtureFiles = {
    { path = "assets/Pinokio-7.2.6.AppImage", content = "appimage-new" },
    { path = "home/pinokio/reqpack/app.json", content = [[{"version":"7.1.12","install_root":"${fixtureRoot}/home/pinokio/app/Pinokio.AppImage"}]] },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "chmod +x '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-28T13:00:00Z\n", stderr = "", success = true },
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
