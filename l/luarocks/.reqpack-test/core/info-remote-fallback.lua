return {
  name = "luarocks info remote fallback search",
  request = {
    action = "info",
    system = "luarocks",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "lpeg",
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
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree show --porcelain lpeg",
      exitCode = 1,
      stdout = "",
      stderr = "not installed\n",
      success = false,
    },
    {
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks search --porcelain lpeg",
      exitCode = 0,
      stdout = "lpeg\t1.1.0-2\tall\thttps://luarocks.org\t\nlpeglabel\t1.6.2-1\tall\thttps://luarocks.org\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "lpeg",
    resultVersion = "1.1.0-2",
    events = { "informed" },
  }
}
