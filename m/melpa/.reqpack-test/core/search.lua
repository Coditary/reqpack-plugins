return {
  name = "melpa search packages",
  request = {
    action = "search",
    system = "melpa",
    prompt = "package",
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
      match = "REQPACK_MELPA_ACTION='search'",
      exitCode = 0,
      stdout = "use-package\t2.4\t2.4\ttrue\tinstalled\tA configuration macro\tA configuration macro\thttps://github.com/jwiegley/use-package\tbind-key\tmelpa\n",
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
