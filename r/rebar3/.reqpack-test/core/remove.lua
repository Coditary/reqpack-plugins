return {
  name = "rebar3 remove dependency",
  request = {
    action = "remove",
    system = "rebar3",
    packages = {
      { name = "cowboy" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/rebar3/project",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/rebar3/project/rebar.config",
      content = [[
{deps, [
    {cowboy, "2.10.0"}
] }.
]],
    },
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
      match = "cat '/home/test/.cache/reqpack/rebar3/project/rebar.config'",
      exitCode = 0,
      stdout = "{deps, [\n    {cowboy, \"2.10.0\"}\n] }.\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[mkdir -p '/home/test/.cache/reqpack/rebar3/project' && printf %s '{deps, [
]}.

' > '/home/test/.cache/reqpack/rebar3/project/rebar.config']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/home/test/.cache/reqpack/rebar3/project' && REBAR_CACHE_DIR='/home/test/.cache/reqpack/rebar3/cache' REBAR_GLOBAL_CONFIG_DIR='/home/test/.cache/reqpack/rebar3/config' REBAR_COLOR='low' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' rebar3 unlock cowboy",
      exitCode = 0,
      stdout = "===> Unlocking dependencies...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
