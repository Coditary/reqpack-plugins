return {
  name = "elpa info package",
  request = {
    action = "info",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    prompt = "use-package",
  },
  fakeExec = {
    {
      match = " info '${fixtureRoot}/.reqpack-data/elpa' 'use-package'",
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
    events = { "informed" },
  }
}
