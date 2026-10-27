return {
  name = "luarocks info local show porcelain",
  request = {
    action = "info",
    system = "luarocks",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "luasocket",
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
      match = "XDG_CACHE_HOME=${fixtureRoot}/.reqpack-data/cache XDG_CONFIG_HOME=${fixtureRoot}/.reqpack-data/config luarocks --tree ${fixtureRoot}/.reqpack-data/tree show --porcelain luasocket",
      exitCode = 0,
      stdout = "package\tluasocket\nversion\t3.1.0-1\nsummary\tNetwork support for Lua\ndetailed\tComprehensive networking support for Lua.\nlicense\tMIT\nhomepage\thttps://github.com/lunarmodules/luasocket\nlocation\t${fixtureRoot}/.reqpack-data/tree\nmodule\tsocket\t${fixtureRoot}/.reqpack-data/tree/share/lua/5.4/socket.lua\ncommand\tluasocket-tool\t${fixtureRoot}/.reqpack-data/tree/bin/luasocket-tool\ndependency\tlua >= 5.1\tusing 5.4\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "luasocket",
    resultVersion = "3.1.0-1",
    events = { "informed" },
  }
}
