return {
  name = "opa install source target",
  request = {
    action = "install",
    system = "opa",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "api",
      "compile",
    },
    packages = {
      { name = "${fixtureRoot}/workspace/hello.opa" }
    },
  },
  fixtureRoot = "/tmp/opencode/opa-install",
  fixtureDirs = {
    "workspace",
    ".reqpack-data/opa",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/workspace/hello.opa",
      content = "package hello\ndo println(\"hi\")\n",
    },
    {
      path = "${fixtureRoot}/workspace/hello.opx/dummy",
      content = "compiled\n",
    },
    {
      path = "${fixtureRoot}/workspace/hello.api",
      content = "{}\n",
    },
  },
  fakeExec = {
    { match = "command -v 'opa' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa --version", exitCode = 0, stdout = "Opa 1.0.7\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa -c --api '${fixtureRoot}/workspace/hello.opa'", exitCode = 0, stdout = "built\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.api'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.api-txt'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'opa/${fixtureRoot}/workspace/hello.opa\thello\t${fixtureRoot}/workspace/hello.opa\tsource\tcompile\t${fixtureRoot}/workspace/hello.opx|${fixtureRoot}/workspace/hello.api\n' > '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    resultCount = 0,
  },
}
