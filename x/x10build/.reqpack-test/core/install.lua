return {
  name = "x10build install release",
  request = {
    action = "install",
    system = "x10build",
    flags = {
      "cache-root=${fixtureRoot}/cache",
      "data-root=${fixtureRoot}/data",
    },
    packages = {
      { name = "x10", version = "2.6.2" }
    },
  },
  fixtureRoot = "../fixtures-install",
  fixtureDirs = {
    "cache/releases",
    "cache/archives",
    "cache/sources",
    "data/metadata",
    "data/installs",
  },
  fixtureFiles = {
    {
      path = "cache/releases/2.6.2.json",
      content = [[{"tag_name":"SF_RELEASE_2_6_2","name":"X10 2.6.2","html_url":"https://github.com/x10-lang/x10/releases/tag/SF_RELEASE_2_6_2","tarball_url":"https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2","body":"X10 Release 2.6.2"}]],
    },
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
    { match = "cat '${fixtureRoot}/cache/releases/2.6.2.json'", exitCode = 0, stdout = [[{"tag_name":"SF_RELEASE_2_6_2","name":"X10 2.6.2","html_url":"https://github.com/x10-lang/x10/releases/tag/SF_RELEASE_2_6_2","tarball_url":"https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2","body":"X10 Release 2.6.2"}]], stderr = "", success = true },
    { match = "curl -fsSL 'https://api.github.com/repos/x10-lang/x10/releases/tags/SF_RELEASE_2_6_2' -o '${fixtureRoot}/cache/releases/2.6.2.json'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/cache/archives/x10-2.6.2.tar.gz'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "curl -fsSL 'https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2' -o '${fixtureRoot}/cache/archives/x10-2.6.2.tar.gz'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '${fixtureRoot}/cache/sources/x10-2.6.2/x10.dist'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "rm -rf '${fixtureRoot}/cache/sources/x10-2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/cache/sources/x10-2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "tar -xzf '${fixtureRoot}/cache/archives/x10-2.6.2.tar.gz' -C '${fixtureRoot}/cache/sources/x10-2.6.2' --strip-components=1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "sh -lc ", exitCode = 0, stdout = "build ok\n", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/data/installs/2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/data/installs'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '${fixtureRoot}/cache/sources/x10-2.6.2/x10.dist' '${fixtureRoot}/data/installs/2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/data/metadata' && printf %s ", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "installed", "success" },
  },
}
