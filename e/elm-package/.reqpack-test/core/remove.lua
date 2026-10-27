return {
  name = "elm-package remove manifest dependency",
  request = {
    action = "remove",
    system = "elm-package",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    packages = {
      { name = "elm-lang/core" }
    },
  },
  fixtureFiles = {
    ["project/elm-package.json"] = [[{"version":"1.0.0","summary":"demo","repository":"http://example.com/demo.git","license":"BSD3","source-directories":["src"],"exposed-modules":[],"dependencies":{"elm-lang/core":"5.1.1 <= v < 6.0.0","elm-lang/html":"2.0.0 <= v < 3.0.0"},"elm-version":"0.18.0 <= v < 0.19.0"}]],
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/project/elm-package.json'",
      exitCode = 0,
      stdout = [[{"version":"1.0.0","summary":"demo","repository":"http://example.com/demo.git","license":"BSD3","source-directories":["src"],"exposed-modules":[],"dependencies":{"elm-lang/core":"5.1.1 <= v < 6.0.0","elm-lang/html":"2.0.0 <= v < 3.0.0"},"elm-version":"0.18.0 <= v < 0.19.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/project' && printf %s '{\"dependencies\":{\"elm-lang/html\":\"2.0.0 <= v < 3.0.0\"},\"elm-version\":\"0.18.0 <= v < 0.19.0\",\"exposed-modules\":[],\"license\":\"BSD3\",\"repository\":\"http://example.com/demo.git\",\"source-directories\":[\"src\"],\"summary\":\"demo\",\"version\":\"1.0.0\"}' > '${fixtureRoot}/project/elm-package.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/project/elm-stuff/exact-dependencies.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{name=elm-lang/core}",
      success = "ok",
    },
  },
}
