return {
  name = "opa info local target",
  request = {
    action = "info",
    system = "opa",
    prompt = "${fixtureRoot}/workspace/hello.opa",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "api",
    },
  },
  fixtureRoot = "/tmp/opencode/opa-info",
  fixtureDirs = {
    "workspace/hello.opx",
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
      path = "${fixtureRoot}/workspace/hello.api",
      content = "{}\n",
    },
  },
  fakeExec = {
    { match = "test -e '${fixtureRoot}/workspace/hello.opa'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v 'opa' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL=C LANG=C LANGUAGE=C opa --version", exitCode = 0, stdout = "Opa 1.0.7\n", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.opx'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/_build'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.exe'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -e '${fixtureRoot}/workspace/hello.api'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -e '${fixtureRoot}/workspace/hello.api-txt'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "hello",
  },
}
