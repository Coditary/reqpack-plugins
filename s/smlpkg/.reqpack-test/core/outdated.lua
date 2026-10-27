return {
  name = "smlpkg detect outdated requirement",
  fixtureRoot = "/tmp/opencode/smlpkg-outdated-case",
  request = {
    action = "outdated",
    system = "smlpkg",
    flags = { "root=/tmp/opencode/smlpkg-outdated-case" },
  },
  fixtureDirs = {
    "lib/github.com/diku-dk/sml-random",
  },
  fixtureFiles = {
    {
      path = "sml.pkg",
      content = "require {\n  github.com/diku-dk/sml-random 1.2.3\n}\n",
    },
    {
      path = "lib/github.com/diku-dk/sml-random/.keep",
      content = "",
    },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/smlpkg-outdated-case/sml.pkg'", exitCode = 0, stdout = "require {\n  github.com/diku-dk/sml-random 1.2.3\n}\n", stderr = "", success = true },
    { match = "command -v smlpkg >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg versions 'github.com/diku-dk/sml-random'", exitCode = 0, stdout = "1.2.3\n1.3.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "github.com/diku-dk/sml-random",
    resultVersion = "1.2.3",
  },
}
