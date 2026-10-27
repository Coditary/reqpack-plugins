return {
  name = "pinokio install script repo",
  request = {
    action = "install",
    system = "pinokio",
    packages = { { name = "script:pinokiocomputer/foo" } },
  },
  fixtureRoot = "../fixtures-install-script",
  fixtureDirs = {
    "home/pinokio/api",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "git clone 'https://github.com/pinokiocomputer/foo.git' '", exitCode = 0, stdout = "cloned\n", stderr = "", success = true },
    { match = "remote get-url origin", exitCode = 0, stdout = "https://github.com/pinokiocomputer/foo.git\n", stderr = "", success = true },
    { match = "rev-parse --short HEAD", exitCode = 0, stdout = "abc123\n", stderr = "", success = true },
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
