return {
  name = "cabal install library",
  request = {
    action = "install",
    system = "cabal",
    packages = {
      { name = "text", version = "2.1.1", flags = { "kind=library" } }
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
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal install --lib text-2.1.1 --package-env /home/test/.cache/reqpack/cabal/home/reqpack/reqpack.env",
      exitCode = 0,
      stdout = "Installed text\n",
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
      match = [[mkdir -p '/home/test/.cache/reqpack/cabal/home/reqpack' && printf %s 'library	text	2.1.1	text-2.1.1		false	text-2.1.1
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
