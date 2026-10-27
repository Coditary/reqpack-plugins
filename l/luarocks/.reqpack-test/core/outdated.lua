return {
  name = "luarocks outdated managed rocks",
  request = {
    action = "outdated",
    system = "luarocks",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
  },
  fakeExec = {
    {
      match = "command -v luarocks >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree list --outdated --porcelain",
      exitCode = 0,
      stdout = "luasocket\t3.0rc1-2\t3.1.0-1\thttps://luarocks.org\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "luasocket",
    resultVersion = "3.0rc1-2",
  }
}
