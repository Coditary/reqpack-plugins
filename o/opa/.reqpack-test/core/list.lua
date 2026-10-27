return {
  name = "opa list known targets",
  request = {
    action = "list",
    system = "opa",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
  },
  fixtureRoot = "/tmp/opencode/opa-list",
  fixtureDirs = {
    "workspace/hello.opx",
    ".reqpack-data/opa",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/opa/inventory.tsv",
      content = "opa/${fixtureRoot}/workspace/hello.opa\thello\t${fixtureRoot}/workspace/hello.opa\tsource\tcompile\t${fixtureRoot}/workspace/hello.opx\n",
    },
  },
  fakeExec = {
    { match = "command -v 'opa' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa --version", exitCode = 0, stdout = "Opa 1.0.7\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 0, stdout = "opa/${fixtureRoot}/workspace/hello.opa\thello\t${fixtureRoot}/workspace/hello.opa\tsource\tcompile\t${fixtureRoot}/workspace/hello.opx\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "hello",
  },
}
