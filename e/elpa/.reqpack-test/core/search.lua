return {
  name = "elpa search packages",
  request = {
    action = "search",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    prompt = "package",
  },
  fakeExec = {
    {
      match = " search '${fixtureRoot}/.reqpack-data/elpa' 'package'",
      exitCode = 0,
      stdout = "use-package\t2.4\t2.4\tfalse\tavailable\tConfiguration macro\tConfiguration macro\thttps://github.com/jwiegley/use-package\tbind-key\tnongnu\tMIT\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "use-package",
    resultVersion = "2.4",
    events = { "searched" },
  }
}
