return {
  name = "hardhat remove installed version",
  request = {
    action = "remove",
    system = "hardhat",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { name = "hardhat", version = "3.7.0" },
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/hardhat/records",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/hardhat/records/hardhat_3_7_0.tsv",
      content = "id\thardhat@3.7.0\nname\thardhat\nversion\t3.7.0\ninstallPath\t${fixtureRoot}/.reqpack-data/hardhat/installs/3.7.0\nlauncherPath\t${fixtureRoot}/.reqpack-data/hardhat/bin/hardhat-3.7.0\nrecordPath\t${fixtureRoot}/.reqpack-data/hardhat/records/hardhat_3_7_0.tsv\ncacheRoot\t${fixtureRoot}/.reqpack-cache/hardhat\nnpmCacheDir\t${fixtureRoot}/.reqpack-cache/hardhat/npm-cache\nhomepage\thttps://hardhat.org\nsourceUrl\thttps://github.com/NomicFoundation/hardhat\nsummary\tEthereum development environment\ndescription\tEthereum development environment\nsourceKind\tregistry\nupdatedAt\t0\n",
    },
  },
  fakeExec = {
    {
      match = "ls -1A '${fixtureRoot}/.reqpack-data/hardhat/records'",
      exitCode = 0,
      stdout = "hardhat_3_7_0.tsv\n",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/.reqpack-data/hardhat/installs/3.7.0'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/.reqpack-data/hardhat/bin/hardhat-3.7.0'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/.reqpack-data/hardhat/records/hardhat_3_7_0.tsv'",
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
