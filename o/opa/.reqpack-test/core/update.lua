return {
  name = "opa update rebuilds known target",
  request = {
    action = "update",
    system = "opa",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
    packages = {
      { name = "${fixtureRoot}/workspace/hello.opa" }
    },
  },
  fixtureRoot = "/tmp/opencode/opa-update",
  fixtureDirs = {
    "workspace",
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
  },
  fakeExec = {
    { match = "command -v 'opa' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa --version", exitCode = 0, stdout = "Opa 1.0.7\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa '${fixtureRoot}/workspace/hello.opa'", exitCode = 0, stdout = "rebuilt\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'opa/${fixtureRoot}/workspace/hello.opa\thello\t${fixtureRoot}/workspace/hello.opa\tsource\tbuild\t${fixtureRoot}/workspace/hello.opx\n' > '${fixtureRoot}/.reqpack-data/opa/inventory.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa --version", exitCode = 0, stdout = "Opa 1.0.7\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "installed", "success", "updated", "success" },
  },
}
