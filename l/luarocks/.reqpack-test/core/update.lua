return {
  name = "luarocks update managed rock",
  request = {
    action = "update",
    system = "luarocks",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "luasocket" }
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
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree install luasocket",
      exitCode = 0,
      stdout = "Installing https://luarocks.org/luasocket-3.1.0-1.src.rock\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v luarocks >/dev/null 2>&1",
      "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree install luasocket"
    },
    events = { "updated", "success" },
  }
}
