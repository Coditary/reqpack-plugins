return {
  name = "elpa install package",
  request = {
    action = "install",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    packages = {
      { action = "install", name = "use-package" }
    },
  },
  fakeExec = {
    {
      match = " install '${fixtureRoot}/.reqpack-data/elpa' 'use-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
