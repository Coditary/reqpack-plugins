return {
  name = "smlpkg info combines local and latest version",
  fixtureRoot = "/tmp/opencode/smlpkg-info-case",
  request = {
    action = "info",
    system = "smlpkg",
    prompt = "github.com/diku-dk/sml-random",
    flags = { "root=/tmp/opencode/smlpkg-info-case" },
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
    { match = "cat '/tmp/opencode/smlpkg-info-case/sml.pkg'", exitCode = 0, stdout = "require {\n  github.com/diku-dk/sml-random 1.2.3\n}\n", stderr = "", success = true },
    { match = "command -v smlpkg >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg versions 'github.com/diku-dk/sml-random'", exitCode = 0, stdout = "1.2.3\n1.3.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "github.com/diku-dk/sml-random",
    resultVersion = "1.2.3",
  },
}
