return {
  name = "smlpkg list manifest requirements",
  fixtureRoot = "/tmp/opencode/smlpkg-list-case",
  request = {
    action = "list",
    system = "smlpkg",
    flags = { "root=/tmp/opencode/smlpkg-list-case" },
  },
  fixtureDirs = {
    "lib/github.com/diku-dk/sml-random",
  },
  fixtureFiles = {
    {
      path = "sml.pkg",
      content = "package github.com/example/app\n\nrequire {\n  github.com/diku-dk/sml-random 1.2.3 #deadbeef\n}\n",
    },
    {
      path = "lib/github.com/diku-dk/sml-random/.keep",
      content = "",
    },
  },
  fakeExec = {
    { match = "cat '/tmp/opencode/smlpkg-list-case/sml.pkg'", exitCode = 0, stdout = "package github.com/example/app\n\nrequire {\n  github.com/diku-dk/sml-random 1.2.3 #deadbeef\n}\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "github.com/diku-dk/sml-random",
    resultVersion = "1.2.3",
  },
}
