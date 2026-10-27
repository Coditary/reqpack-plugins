return {
  name = "cabal install local target",
  request = {
    action = "install",
    system = "cabal",
    localPath = "/tmp/reqpack-cabal/demo",
    packages = {
      { name = "demo-tool" }
    },
  },
  fixtureDirs = {
    "/tmp/reqpack-cabal/demo",
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
      match = "test -e '/tmp/reqpack-cabal/demo'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal install /tmp/reqpack-cabal/demo --installdir=/home/test/.cache/reqpack/cabal/bin --install-method=copy --overwrite-policy=always",
      exitCode = 0,
      stdout = "Installed local demo\n",
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
      match = [[mkdir -p '/home/test/.cache/reqpack/cabal/home/reqpack' && printf %s 'executable	demo		/tmp/reqpack-cabal/demo	demo	true	/tmp/reqpack-cabal/demo
' > '/home/test/.cache/reqpack/cabal/home/reqpack/installs.tsv']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
