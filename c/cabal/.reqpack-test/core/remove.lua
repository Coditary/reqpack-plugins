return {
  name = "cabal remove executable metadata",
  request = {
    action = "remove",
    system = "cabal",
    packages = {
      { name = "hlint" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/cabal/home/reqpack",
    "/home/test/.cache/reqpack/cabal/bin",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv",
      content = "executable\thlint\t3.8\thlint-3.8\thlint\tfalse\thlint-3.8\n",
    },
    {
      path = "/home/test/.cache/reqpack/cabal/bin/hlint",
      content = "binary",
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
