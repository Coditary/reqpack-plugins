return {
  name = "cabal update executable",
  request = {
    action = "update",
    system = "cabal",
    packages = {
      { name = "hlint", version = "3.9" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/cabal/home/reqpack",
    "/home/test/.cache/reqpack/cabal/bin",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv",
      content = "executable\thlint\t3.8\thlint-3.8\thlint\tfalse\thlint-3.8\n",
    },
  },
  fakeExec = {
    {
      match = "command -v 'cabal' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal update",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal install hlint-3.9 --installdir=/home/test/.cache/reqpack/cabal/bin --install-method=copy --overwrite-policy=always",
      exitCode = 0,
      stdout = "Updated hlint\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv'",
      exitCode = 0,
      stdout = [[executable	hlint	3.8	hlint-3.8	hlint	false	hlint-3.8
]],
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '/home/test/.cache/reqpack/cabal/home/reqpack' && printf %s 'executable	hlint	3.9	hlint-3.9	hlint	false	hlint-3.9
' > '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
