return {
  name = "elpa update all packages",
  request = {
    action = "update",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
  },
  fakeExec = {
    {
      match = " update-all '${fixtureRoot}/.reqpack-data/elpa'",
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
