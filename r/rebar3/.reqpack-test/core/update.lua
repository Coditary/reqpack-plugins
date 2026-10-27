return {
  name = "rebar3 update dependency",
  request = {
    action = "update",
    system = "rebar3",
    packages = {
      { name = "cowboy", version = "2.11.0" }
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
    {cowboy, "2.11.0"}
]}.

' > '/home/test/.cache/reqpack/rebar3/project/rebar.config']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "REBAR_CACHE_DIR='/home/test/.cache/reqpack/rebar3/cache' REBAR_GLOBAL_CONFIG_DIR='/home/test/.cache/reqpack/rebar3/config' REBAR_COLOR='low' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' rebar3 update",
      exitCode = 0,
      stdout = "===> Updating package index...\n",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/home/test/.cache/reqpack/rebar3/project' && REBAR_CACHE_DIR='/home/test/.cache/reqpack/rebar3/cache' REBAR_GLOBAL_CONFIG_DIR='/home/test/.cache/reqpack/rebar3/config' REBAR_COLOR='low' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' rebar3 upgrade",
      exitCode = 0,
      stdout = "===> Upgrading dependencies...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
