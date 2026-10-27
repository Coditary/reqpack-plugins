return {
  name = "rebar3 list direct dependencies",
  request = {
    action = "list",
    system = "rebar3",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/rebar3/project",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/rebar3/project/rebar.config",
      content = [[
{deps, [
    {cowboy, "2.10.0"},
    ranch,
    {localdep, {git, "/tmp/localdep"}}
] }.
]],
    },
  },
  fakeExec = {
    {
      match = "cat '/home/test/.cache/reqpack/rebar3/project/rebar.config'",
      exitCode = 0,
      stdout = "{deps, [\n    {cowboy, \"2.10.0\"},\n    ranch,\n    {localdep, {git, \"/tmp/localdep\"}}\n] }.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 3,
    resultName = "cowboy",
    events = { "listed" },
  },
}
