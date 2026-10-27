return {
  name = "elm-package install remote dependency",
  request = {
    action = "install",
    system = "elm-package",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
    packages = {
      { name = "elm-lang/core", version = "5.1.1" }
    },
  },
  fixtureFiles = {
    ["project/elm-package.json"] = [[{"version":"1.0.0","summary":"demo","repository":"http://example.com/demo.git","license":"BSD3","source-directories":["src"],"exposed-modules":[],"dependencies":{},"elm-version":"0.18.0 <= v < 0.19.0"}]],
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
      stdout = [[{"version":"1.0.0","summary":"demo","repository":"http://example.com/demo.git","license":"BSD3","source-directories":["src"],"exposed-modules":[],"dependencies":{},"elm-version":"0.18.0 <= v < 0.19.0"}]],
      stderr = "",
      success = true,
    },
    {
      match = "elm-package install --yes elm-lang/core 5.1.1",
      exitCode = 0,
      stdout = "Installed elm-lang/core 5.1.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v elm-package >/dev/null 2>&1",
      "cat '${fixtureRoot}/project/elm-package.json'",
      "elm-package install --yes elm-lang/core 5.1.1",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{name=elm-lang/core, projectRoot=${fixtureRoot}/project, version=5.1.1}",
      success = "ok",
    },
  },
}
