return {
  name = "opa remove generated outputs",
  request = {
    action = "remove",
    system = "opa",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
    packages = {
      { name = "${fixtureRoot}/workspace/hello.opa" }
    },
  },
  fixtureRoot = "/tmp/opencode/opa-remove",
  fixtureDirs = {
    "workspace/hello.opx",
    ".reqpack-data/opa",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/workspace/hello.opa",
      content = "package hello\n",
    },
    {
      path = "${fixtureRoot}/workspace/hello.opx/dummy",
      content = "compiled\n",
    },
    {
      path = "${fixtureRoot}/.reqpack-data/opa/inventory.tsv",
      content = "opa/${fixtureRoot}/workspace/hello.opa\thello\t${fixtureRoot}/workspace/hello.opa\tsource\tbuild\t${fixtureRoot}/workspace/hello.opx|${fixtureRoot}/workspace/_build\n",
    },
  },
  fakeExec = {
    { match = "test -e '${fixtureRoot}/workspace/hello.opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 0, stdout = "opa/${fixtureRoot}/workspace/hello.opa\thello\t${fixtureRoot}/workspace/hello.opa\tsource\tbuild\t${fixtureRoot}/workspace/hello.opx|${fixtureRoot}/workspace/_build\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "rm -rf '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '' > '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
