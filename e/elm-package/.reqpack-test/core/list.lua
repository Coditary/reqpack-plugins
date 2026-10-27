return {
  name = "elm-package list exact dependencies",
  request = {
    action = "list",
    system = "elm-package",
    flags = {
      "cwd=${fixtureRoot}/project",
      "cache-root=${fixtureRoot}/cache",
    },
  },
  fixtureFiles = {
    ["project/elm-stuff/exact-dependencies.json"] = [[{"elm-lang/core":"5.1.1","elm-lang/html":"2.0.0"}]],
    ["cache/registry/all-packages.json"] = [=[[{"name":"elm-lang/core","summary":"Elm core","versions":["5.1.1"]},{"name":"elm-lang/html","summary":"Elm html","versions":["2.0.0"]}]]=],
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/project/elm-stuff/exact-dependencies.json'",
      exitCode = 0,
      stdout = [[{"elm-lang/core":"5.1.1","elm-lang/html":"2.0.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/cache/registry/all-packages.json'",
      exitCode = 0,
      stdout = [=[[{"name":"elm-lang/core","summary":"Elm core","versions":["5.1.1"]},{"name":"elm-lang/html","summary":"Elm html","versions":["2.0.0"]}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "elm-lang/core",
    resultVersion = "5.1.1",
  },
}
