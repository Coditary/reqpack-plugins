return {
  name = "pinto update root distributions",
  request = {
    action = "update",
    system = "pinto",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "stack=trial" },
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
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'update' '--stack' 'trial' '--use-default-message' '--roots'",
      exitCode = 0,
      stdout = "Updated roots\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
