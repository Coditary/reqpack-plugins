return {
  name = "cabal install executable",
  request = {
    action = "install",
    system = "cabal",
    packages = {
      { name = "hlint", version = "3.8" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/cabal/home/reqpack",
    "/home/test/.cache/reqpack/cabal/bin",
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
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal install hlint-3.8 --installdir=/home/test/.cache/reqpack/cabal/bin --install-method=copy --overwrite-policy=always",
      exitCode = 0,
      stdout = "Installed hlint\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv'",
      exitCode = 1,
      stdout = "",
      stderr = "missing",
      success = false,
    },
    {
      match = [[mkdir -p '/home/test/.cache/reqpack/cabal/home/reqpack' && printf %s 'executable	hlint	3.8	hlint-3.8	hlint	false	hlint-3.8
' > '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'cabal' >/dev/null 2>&1",
      "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal update",
      "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal install hlint-3.8 --installdir=/home/test/.cache/reqpack/cabal/bin --install-method=copy --overwrite-policy=always",
      "cat '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv'",
      [[mkdir -p '/home/test/.cache/reqpack/cabal/home/reqpack' && printf %s 'executable	hlint	3.8	hlint-3.8	hlint	false	hlint-3.8
' > '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv']]
    },
    events = { "installed", "success" },
  },
}
