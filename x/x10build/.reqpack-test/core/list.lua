return {
  name = "x10build list installed",
  request = {
    action = "list",
    system = "x10build",
    flags = {
      "data-root=${fixtureRoot}/data",
    },
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "data/metadata",
    "cache/releases",
  },
  fixtureFiles = {
    {
      path = "data/metadata/installed.txt",
      content = "name=x10\nversion=2.6.2\ninstallPath=${fixtureRoot}/data/installs/2.6.2\nbinPath=${fixtureRoot}/data/installs/2.6.2/bin\nsourceKind=release\nsummary=X10 language compiler and runtime\ndescription=Official X10 toolchain built from upstream release or local source tree\n",
    },
    {
      path = "cache/releases/latest.json",
      content = [[{"tag_name":"SF_RELEASE_2_6_2","name":"X10 2.6.2","html_url":"https://github.com/x10-lang/x10/releases/tag/SF_RELEASE_2_6_2","tarball_url":"https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2","zipball_url":"https://api.github.com/repos/x10-lang/x10/zipball/SF_RELEASE_2_6_2","body":"X10 Release 2.6.2","published_at":"2019-01-04T22:28:26Z","draft":false,"prerelease":false,"assets":[{"name":"x10-dist.tar.gz","content_type":"application/gzip","size":1234,"download_count":7,"browser_download_url":"https://github.com/x10-lang/x10/releases/download/SF_RELEASE_2_6_2/x10-dist.tar.gz"}]}]],
    },
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "${fixtureRoot}",
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/data/metadata/installed.txt'", exitCode = 0, stdout = "name=x10\nversion=2.6.2\ninstallPath=${fixtureRoot}/data/installs/2.6.2\nbinPath=${fixtureRoot}/data/installs/2.6.2/bin\nsourceKind=release\nsummary=X10 language compiler and runtime\ndescription=Official X10 toolchain built from upstream release or local source tree\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/cache/releases/latest.json'", exitCode = 0, stdout = [[{"tag_name":"SF_RELEASE_2_6_2","name":"X10 2.6.2","html_url":"https://github.com/x10-lang/x10/releases/tag/SF_RELEASE_2_6_2","tarball_url":"https://api.github.com/repos/x10-lang/x10/tarball/SF_RELEASE_2_6_2","zipball_url":"https://api.github.com/repos/x10-lang/x10/zipball/SF_RELEASE_2_6_2","body":"X10 Release 2.6.2","published_at":"2019-01-04T22:28:26Z","draft":false,"prerelease":false,"assets":[{"name":"x10-dist.tar.gz","content_type":"application/gzip","size":1234,"download_count":7,"browser_download_url":"https://github.com/x10-lang/x10/releases/download/SF_RELEASE_2_6_2/x10-dist.tar.gz"}]}]], stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "x10",
    resultVersion = "2.6.2",
    events = { "listed" },
  },
}
