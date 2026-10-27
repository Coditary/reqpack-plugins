return {
  name = "cabal list cached entries",
  request = {
    action = "list",
    system = "cabal",
  },
  fakeExec = {
    {
      match = "cat '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv'",
      exitCode = 0,
      stdout = [[executable	hlint	3.8	hlint-3.8	hlint	false	hlint-3.8
library	text	2.1.1	text-2.1.1		false	text-2.1.1
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "hlint",
    resultVersion = "3.8",
  },
}
