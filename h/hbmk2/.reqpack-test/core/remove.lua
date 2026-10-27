return {
  name = "hbmk2 remove tracked package",
  request = {
    action = "remove",
    system = "hbmk2",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
    packages = {
      { name = "hbct" }
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/cache"
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/cache/tracked-packages.txt",
      content = "hbct.hbc\nhbtip.hbc\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'hbmk2' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/cache/tracked-packages.txt'",
      exitCode = 0,
      stdout = "hbct.hbc\nhbtip.hbc\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'hbmk2' >/dev/null 2>&1",
      "cat '${fixtureRoot}/cache/tracked-packages.txt'",
    },
    events = { "deleted", "success" },
  }
}
