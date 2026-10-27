return {
  name = "x10build install local source tree",
  request = {
    action = "install",
    system = "x10build",
    localPath = "${fixtureRoot}/source/x10-2.6.1-src",
    flags = {
      "cache-root=${fixtureRoot}/cache",
      "data-root=${fixtureRoot}/data",
    },
    packages = {
      { name = "x10", version = "2.6.1" }
    },
  },
  fixtureRoot = "../fixtures-install-local",
  fixtureDirs = {
    "source/x10-2.6.1-src/x10.dist",
    "cache/releases",
    "cache/archives",
    "cache/sources",
    "data/metadata",
    "data/installs",
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v 'tar' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v 'ant' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/cache/releases'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/cache/archives'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/cache/sources'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/data/installs'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/data/metadata'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '${fixtureRoot}/source/x10-2.6.1-src'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "sh -lc ", exitCode = 0, stdout = "build ok\n", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/data/installs/2.6.1'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/data/installs'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '${fixtureRoot}/source/x10-2.6.1-src/x10.dist' '${fixtureRoot}/data/installs/2.6.1'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "installed", "success" },
  },
}
