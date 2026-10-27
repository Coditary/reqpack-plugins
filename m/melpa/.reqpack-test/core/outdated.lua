return {
  name = "melpa list outdated packages",
  request = {
    action = "outdated",
    system = "melpa",
  },
  fakeExec = {
    {
      match = "command -v 'emacs' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "REQPACK_MELPA_ACTION='outdated'",
      exitCode = 0,
      stdout = "use-package\t2.3\t2.4\ttrue\toutdated\tA configuration macro\tA configuration macro\thttps://github.com/jwiegley/use-package\tbind-key\tmelpa\n",
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
