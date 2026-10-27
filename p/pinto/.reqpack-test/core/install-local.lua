return {
  name = "pinto add local archive",
  request = {
    action = "install",
    system = "pinto",
    localPath = "${fixtureRoot}/dist/My-App-1.0.tar.gz",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "stack=master", "author=SHAKESPEARE" },
  },
  fixtureDirs = {
    "dist",
    ".reqpack-data/repository/.pinto/config",
  },
  fixtureFiles = {
    {
      path = "dist/My-App-1.0.tar.gz",
      content = "fake archive",
    },
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
      match = "test -f '${fixtureRoot}/dist/My-App-1.0.tar.gz'",
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
      match = "pinto --root '${fixtureRoot}/.reqpack-data/repository' 'add' '--stack' 'master' '--use-default-message' '--author' 'SHAKESPEARE' '${fixtureRoot}/dist/My-App-1.0.tar.gz'",
      exitCode = 0,
      stdout = "Added archive\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
