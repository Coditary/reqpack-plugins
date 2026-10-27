return {
  name = "elpa remove package",
  request = {
    action = "remove",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    packages = {
      { action = "remove", name = "use-package" }
    },
  },
  fakeExec = {
    {
      match = " remove '${fixtureRoot}/.reqpack-data/elpa' 'use-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
