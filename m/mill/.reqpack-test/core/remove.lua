return {
  name = "mill remove installed version",
  request = {
    action = "remove",
    system = "mill",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { name = "mill", version = "1.0.4" },
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/mill/records",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/mill/records/mill_1_0_4.tsv",
      content = "id\tmill@1.0.4\nname\tmill\nversion\t1.0.4\nlauncherPath\t${fixtureRoot}/.reqpack-data/mill/bin/mill-1.0.4\ndownloadPath\t${fixtureRoot}/.reqpack-cache/mill/downloads/mill-1.0.4.sh\nhomepage\thttps://mill-build.org/\nupdatedAt\t0\n",
    },
  },
  fakeExec = {
    {
      match = "ls -1A '${fixtureRoot}/.reqpack-data/mill/records'",
      exitCode = 0,
      stdout = "mill_1_0_4.tsv\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/.reqpack-data/mill/records/mill_1_0_4.tsv'",
      exitCode = 0,
      stdout = "id\tmill@1.0.4\nname\tmill\nversion\t1.0.4\nlauncherPath\t${fixtureRoot}/.reqpack-data/mill/bin/mill-1.0.4\ndownloadPath\t${fixtureRoot}/.reqpack-cache/mill/downloads/mill-1.0.4.sh\nhomepage\thttps://mill-build.org/\nupdatedAt\t0\n",
      stderr = "",
      success = true,
    },
    {
      match = "rm -f '${fixtureRoot}/.reqpack-data/mill/bin/mill-1.0.4'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -f '${fixtureRoot}/.reqpack-data/mill/records/mill_1_0_4.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    result = true,
  }
}
