return {
  name = "pinto unregister package from stack",
  request = {
    action = "remove",
    system = "pinto",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "stack=dev" },
    packages = {
      { name = "URI" },
    },
  },
  fixtureDirs = {
    ".reqpack-data/repository/.pinto/config",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/repository/.pinto/config/pinto.ini",
      content = "[pinto]\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'pinto' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -f '${fixtureRoot}/.reqpack-data/repository/.pinto/config/pinto.ini'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'unregister' '--stack' 'dev' '--use-default-message' 'URI'",
      exitCode = 0,
      stdout = "Unregistered URI\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
