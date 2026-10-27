return {
  name = "x10build update installed to latest",
  request = {
    action = "update",
    system = "x10build",
    flags = {
      "cache-root=.reqpack-test/fixtures-update/cache",
      "data-root=.reqpack-test/fixtures-update/data",
    },
  },
  fixtureRoot = "../fixtures-update",
  fixtureDirs = {
    "cache/releases",
    "cache/archives",
    "cache/sources",
    "data/metadata",
    "data/installs",
  },
  fixtureFiles = {
    {
      path = "data/metadata/installed.txt",
      content = "name=x10\nversion=2.6.1\ninstallPath=.reqpack-test/fixtures-update/data/installs/2.6.1\nbinPath=.reqpack-test/fixtures-update/data/installs/2.6.1/bin\nsourceKind=release\n",
    },
    {
      path = "cache/releases/latest.json",
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
    { match = "mkdir -p '.reqpack-test/fixtures-update/cache/releases'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-test/fixtures-update/cache/archives'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-test/fixtures-update/cache/sources'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-test/fixtures-update/data/installs'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-test/fixtures-update/data/metadata'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/cache/releases/latest.json'", exitCode = 0, stdout = [[{"tag_name":"SF_RELEASE_2_6_2","name":"X10 2.6.2","html_url":"https://github.com/x10-lang/x10/releases/tag/SF_RELEASE_2_6_2","tarball_url":"https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2","body":"X10 Release 2.6.2"}]], stderr = "", success = true },
    { match = "test -f '.reqpack-test/fixtures-update/cache/archives/x10-2.6.2.tar.gz'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "curl -fsSL 'https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2' -o '.reqpack-test/fixtures-update/cache/archives/x10-2.6.2.tar.gz'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '.reqpack-test/fixtures-update/cache/sources/x10-2.6.2/x10.dist'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "rm -rf '.reqpack-test/fixtures-update/cache/sources/x10-2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-test/fixtures-update/cache/sources/x10-2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "tar -xzf '.reqpack-test/fixtures-update/cache/archives/x10-2.6.2.tar.gz' -C '.reqpack-test/fixtures-update/cache/sources/x10-2.6.2' --strip-components=1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "sh -lc 'cd '\''.reqpack-test/fixtures-update/cache/sources/x10-2.6.2/x10.dist'\'' && ant dist'", exitCode = 0, stdout = "build ok\n", stderr = "", success = true },
    { match = "rm -rf '.reqpack-test/fixtures-update/data/installs/2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-test/fixtures-update/data/installs'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '.reqpack-test/fixtures-update/cache/sources/x10-2.6.2/x10.dist' '.reqpack-test/fixtures-update/data/installs/2.6.2'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/data/metadata' && printf %s ", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
  },
}
