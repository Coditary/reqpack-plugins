return {
  name = "cabal outdated from cached install",
  request = {
    action = "outdated",
    system = "cabal",
  },
  fakeExec = {
    {
      match = "cat '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv'",
      exitCode = 0,
      stdout = [[executable	hlint	3.8	hlint-3.8	hlint	false	hlint-3.8
]],
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'cabal' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal list --simple-output hlint",
      exitCode = 0,
      stdout = "hlint 3.8\nhlint 3.9\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "hlint",
    resultVersion = "3.8",
  },
}
