return {
  name = "rebar3 search exact package",
  request = {
    action = "search",
    system = "rebar3",
    prompt = "cowboy",
  },
  fakeExec = {
    {
      match = "command -v 'rebar3' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "REBAR_CACHE_DIR='/home/test/.cache/reqpack/rebar3/cache' REBAR_GLOBAL_CONFIG_DIR='/home/test/.cache/reqpack/rebar3/config' REBAR_COLOR='low' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' rebar3 pkgs cowboy",
      exitCode = 0,
      stdout = "hexpm:\n Name: cowboy\n Description: Small, fast, modern HTTP server\n Licenses: ISC\n Links:\n  github: https://github.com/ninenines/cowboy\n Versions: 2.10.0, 2.11.0\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "cowboy",
    resultVersion = "2.11.0",
    events = { "searched" },
  },
}
