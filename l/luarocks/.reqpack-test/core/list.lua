return {
  name = "luarocks list managed rocks",
  request = {
    action = "list",
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
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree list --porcelain",
      exitCode = 0,
      stdout = "luasocket\t3.1.0-1\trockspec\thttps://luarocks.org\t\nlpeg\t1.1.0-2\tall\thttps://luarocks.org\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v luarocks >/dev/null 2>&1",
      "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree list --porcelain"
    },
    resultCount = 2,
    resultName = "luasocket",
    resultVersion = "3.1.0-1",
    events = { "listed" },
  }
}
