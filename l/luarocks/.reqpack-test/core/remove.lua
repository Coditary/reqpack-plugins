return {
  name = "luarocks remove managed rock",
  request = {
    action = "remove",
    system = "luarocks",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "luasocket", version = "3.1.0-1" }
    },
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
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree remove luasocket 3.1.0-1",
      exitCode = 0,
      stdout = "Removing luasocket 3.1.0-1...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v luarocks >/dev/null 2>&1",
      "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree remove luasocket 3.1.0-1"
    },
    events = { "deleted", "success" },
  }
}
