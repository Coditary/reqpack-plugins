return {
  name = "x10build remove installed version",
  request = {
    action = "remove",
    system = "x10build",
    flags = {
      "data-root=${fixtureRoot}/data",
    },
    packages = {
      { name = "x10" }
    },
  },
  fixtureRoot = "../fixtures-remove",
  fixtureDirs = {
    "data/metadata",
  },
  fixtureFiles = {
    {
      path = "data/metadata/installed.txt",
      content = "name=x10\nversion=2.6.1\ninstallPath=${fixtureRoot}/data/installs/2.6.1\nbinPath=${fixtureRoot}/data/installs/2.6.1/bin\nsourceKind=release\n",
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/data/metadata/installed.txt'", exitCode = 0, stdout = "name=x10\nversion=2.6.1\ninstallPath=${fixtureRoot}/data/installs/2.6.1\nbinPath=${fixtureRoot}/data/installs/2.6.1/bin\nsourceKind=release\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/data/metadata/installed.txt'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/data/installs/2.6.1'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -f '${fixtureRoot}/data/metadata/installed.txt'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "deleted", "success" },
  },
}
