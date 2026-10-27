return {
  name = "elm-package update all dependencies",
  request = {
    action = "update",
    system = "elm-package",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
  },
  fixtureFiles = {
    ["project/elm-package.json"] = [[{"version":"1.0.0","summary":"demo","repository":"http://example.com/demo.git","license":"BSD3","source-directories":["src"],"exposed-modules":[],"dependencies":{"elm-lang/core":"5.1.1 <= v < 6.0.0"},"elm-version":"0.18.0 <= v < 0.19.0"}]],
  },
  fakeExec = {
    {
      match = "command -v elm-package >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/project/elm-package.json'",
      exitCode = 0,
      stdout = [[{"version":"1.0.0","summary":"demo","repository":"http://example.com/demo.git","license":"BSD3","source-directories":["src"],"exposed-modules":[],"dependencies":{"elm-lang/core":"5.1.1 <= v < 6.0.0"},"elm-version":"0.18.0 <= v < 0.19.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "elm-package install --yes",
      exitCode = 0,
      stdout = "Updated dependencies\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
