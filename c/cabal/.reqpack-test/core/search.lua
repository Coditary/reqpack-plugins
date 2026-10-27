return {
  name = "cabal search groups versions",
  request = {
    action = "search",
    system = "cabal",
    prompt = "hlin",
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
      match = "CABAL_DIR='/home/test/.cache/reqpack/cabal/home' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' cabal list --simple-output hlin",
      exitCode = 0,
      stdout = "hlint 3.7\nhlint 3.8\nhlint-refactor 0.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "hlint",
    resultVersion = "3.8",
  },
}
