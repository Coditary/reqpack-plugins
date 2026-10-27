return {
  name = "pinto pull package into repository",
  request = {
    action = "install",
    system = "pinto",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "stack=dev" },
    packages = {
      { name = "URI", version = "1.62" },
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
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'init' '--stack' 'dev'",
      exitCode = 0,
      stdout = "Initialized\n",
      stderr = "",
      success = true,
    },
    {
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'pull' '--stack' 'dev' '--use-default-message' 'URI~1.62'",
      exitCode = 0,
      stdout = "Pulled URI\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'pinto' >/dev/null 2>&1",
      "test -f '${fixtureRoot}/.reqpack-data/repository/.pinto/config/pinto.ini'",
      "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'init' '--stack' 'dev'",
      "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'pull' '--stack' 'dev' '--use-default-message' 'URI~1.62'"
    },
    events = { "installed", "success" },
  },
}
