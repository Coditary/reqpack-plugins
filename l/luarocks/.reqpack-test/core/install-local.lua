return {
  name = "luarocks install local rockspec",
  request = {
    action = "install",
    system = "luarocks",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    localPath = "/tmp/pkg/luafilesystem-1.8.0-1.rockspec",
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
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree install /tmp/pkg/luafilesystem-1.8.0-1.rockspec",
      exitCode = 0,
      stdout = "Installing /tmp/pkg/luafilesystem-1.8.0-1.rockspec\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v luarocks >/dev/null 2>&1",
      "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree install /tmp/pkg/luafilesystem-1.8.0-1.rockspec"
    },
    events = { "installed", "success" },
  }
}
