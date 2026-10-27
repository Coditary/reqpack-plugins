return {
  name = "elpa list outdated packages",
  request = {
    action = "outdated",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
  },
  fakeExec = {
    {
      match = " outdated '${fixtureRoot}/.reqpack-data/elpa'",
      exitCode = 0,
      stdout = "use-package\t2.3\t2.4\ttrue\toutdated\tConfiguration macro\tConfiguration macro\thttps://github.com/jwiegley/use-package\tbind-key\tgnu\tMIT\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "use-package",
    resultVersion = "2.3",
    events = { "outdated" },
  }
}
