return {
  name = "elm-package outdated exact dependencies",
  request = {
    action = "outdated",
    system = "elm-package",
    flags = {
      "cwd=${fixtureRoot}/project",
      "cache-root=${fixtureRoot}/cache",
    },
  },
  fixtureFiles = {
    ["project/elm-stuff/exact-dependencies.json"] = [[{"elm-lang/core":"5.1.0"}]],
    ["cache/registry/all-packages.json"] = [=[[{"name":"elm-lang/core","summary":"Elm core","versions":["5.1.0","5.1.1"]}]]=],
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/project/elm-stuff/exact-dependencies.json'",
      exitCode = 0,
      stdout = [[{"elm-lang/core":"5.1.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/cache/registry/all-packages.json'",
      exitCode = 0,
      stdout = [=[[{"name":"elm-lang/core","summary":"Elm core","versions":["5.1.0","5.1.1"]}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project/elm-stuff/exact-dependencies.json'",
      exitCode = 0,
      stdout = [[{"elm-lang/core":"5.1.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/cache/registry/all-packages.json'",
      exitCode = 0,
      stdout = [=[[{"name":"elm-lang/core","summary":"Elm core","versions":["5.1.0","5.1.1"]}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed", "outdated" },
    resultCount = 1,
    resultName = "elm-lang/core",
  },
}
