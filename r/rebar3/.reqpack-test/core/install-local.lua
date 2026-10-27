return {
  name = "rebar3 install local git dependency",
  request = {
    action = "install",
    system = "rebar3",
    localPath = "/tmp/reqpack-rebar3-local/mydep",
    packages = {
      { name = "mydep" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-rebar3-local/mydep/.git",
    "/home/test/.cache/reqpack/rebar3/project",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/rebar3/project/rebar.config",
      content = [[
{deps, [
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
      match = "test -d '/tmp/reqpack-rebar3-local/mydep/.git'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/rebar3/project/rebar.config'",
      exitCode = 0,
      stdout = "{deps, [\n] }.\n",
      stderr = "",
      success = true,
    },
    {
      match = [=[mkdir -p '/home/test/.cache/reqpack/rebar3/project' && printf %s '{deps, [
    {mydep, {git, "/tmp/reqpack-rebar3-local/mydep"}}
]}.

' > '/home/test/.cache/reqpack/rebar3/project/rebar.config']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cd '/home/test/.cache/reqpack/rebar3/project' && REBAR_CACHE_DIR='/home/test/.cache/reqpack/rebar3/cache' REBAR_GLOBAL_CONFIG_DIR='/home/test/.cache/reqpack/rebar3/config' REBAR_COLOR='low' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' rebar3 get-deps",
      exitCode = 0,
      stdout = "===> Verifying dependencies...\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
