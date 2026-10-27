return {
  name = "cabal info merges installed and remote",
  request = {
    action = "info",
    system = "cabal",
    prompt = "hlint",
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
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal info hlint",
      exitCode = 0,
      stdout = "* hlint (library)\n    Synopsis: Source code suggestions\n    Versions available: 3.7, 3.8, 3.9\n    Versions installed: [ Not installed ]\n    Homepage: https://github.com/ndmitchell/hlint\n    License: BSD-3-Clause\n    Author: Neil Mitchell\n    Maintainer: neil@example.test\n    Category: Development\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "hlint",
    resultVersion = "3.8",
  },
}
