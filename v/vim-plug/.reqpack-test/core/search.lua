return {
  name = "vim-plug search exact remote repo",
  request = {
    action = "search",
    system = "vim-plug",
    prompt = "tpope/vim-sensible",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
  },
  fakeExec = {
    { match = "git ls-remote --symref 'https://github.com/tpope/vim-sensible.git' HEAD refs/heads/* refs/tags/*", exitCode = 0, stdout = "ref: refs/heads/master\tHEAD\n1111111111111111111111111111111111111111\tHEAD\n1111111111111111111111111111111111111111\trefs/heads/master\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "vim-sensible",
    resultVersion = "master",
  },
}
