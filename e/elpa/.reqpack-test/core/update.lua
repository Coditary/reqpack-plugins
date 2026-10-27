return {
  name = "elpa update named package",
  request = {
    action = "update",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    packages = {
      { action = "update", name = "use-package" }
    },
  },
  fakeExec = {
    {
      match = " update '${fixtureRoot}/.reqpack-data/elpa' 'use-package'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
