return {
  name = "elpa list installed packages",
  request = {
    action = "list",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
  },
  fakeExec = {
    {
      match = " list '${fixtureRoot}/.reqpack-data/elpa'",
      exitCode = 0,
      stdout = "use-package\t2.4\t2.4\ttrue\tinstalled\tConfiguration macro\tConfiguration macro\thttps://github.com/jwiegley/use-package\tbind-key\tgnu\tMIT\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "use-package",
    resultVersion = "2.4",
    events = { "listed" },
  }
}
