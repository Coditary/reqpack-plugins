return {
  name = "elm-package search legacy registry",
  request = {
    action = "search",
    system = "elm-package",
    prompt = "core",
    flags = {
      "cache-root=${fixtureRoot}/cache",
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/cache/registry/all-packages.json'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = "curl -fsSL 'https://package.elm-lang.org/all-packages?elm-package-version=0.18'",
      exitCode = 0,
      stdout = [=[[{"name":"elm-lang/core","summary":"Elm core","versions":["5.1.1"]},{"name":"elm-lang/html","summary":"HTML library","versions":["2.0.0"]}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/cache/registry' && printf %s '[{\"name\":\"elm-lang/core\",\"summary\":\"Elm core\",\"versions\":[\"5.1.1\"]},{\"name\":\"elm-lang/html\",\"summary\":\"HTML library\",\"versions\":[\"2.0.0\"]}]' > '${fixtureRoot}/cache/registry/all-packages.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "elm-lang/core",
    resultVersion = "5.1.1",
  },
}
