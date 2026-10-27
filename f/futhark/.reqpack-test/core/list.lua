return {
  name = "futhark list manifest dependencies",
  request = {
    action = "list",
    system = "futhark",
    flags = {
      "cwd=${fixtureRoot}/project",
    },
  },
  fixtureFiles = {
    ["project/futhark.pkg"] = [=[package github.com/acme/app

require {
  github.com/diku-dk/array 1.2.3 #abc123
  github.com/foo/bar@2 2.0.0
}
]=],
  },
  fixtureDirs = {
    "project/lib/github.com/diku-dk/array",
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/project/futhark.pkg'",
      exitCode = 0,
      stdout = [=[package github.com/acme/app

require {
  github.com/diku-dk/array 1.2.3 #abc123
  github.com/foo/bar@2 2.0.0
}
]=],
      stderr = "",
      success = true,
    },
    {
      match = "test -d '${fixtureRoot}/project/lib/github.com/diku-dk/array'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '${fixtureRoot}/project/lib/github.com/foo/bar@2'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "github.com/diku-dk/array",
    resultVersion = "1.2.3",
  },
}
