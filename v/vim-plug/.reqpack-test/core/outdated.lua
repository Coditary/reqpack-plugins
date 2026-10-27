return {
  name = "vim-plug outdated compares local and remote revision",
  request = {
    action = "outdated",
    system = "vim-plug",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
  },
  fixtureDirs = {
    ".reqpack-data/vim-plug",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/vim-plug/manifest.tsv",
      content = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\n",
    },
    {
      path = ".reqpack-data/vim-plug/state.tsv",
      content = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\tmaster\t1111111111111111111111111111111111111111\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\tinstalled\n",
    },
  },
  fakeExec = {
    { match = "command -v 'git' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/vim-plug/manifest.tsv'", exitCode = 0, stdout = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/vim-plug/state.tsv'", exitCode = 0, stdout = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\tmaster\t1111111111111111111111111111111111111111\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\tinstalled\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/vim-plug/remote-info.tsv'", exitCode = 1, stdout = "", stderr = "missing", success = false },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-cache/vim-plug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'tpope/vim-sensible\tvim-sensible\ttpope/vim-sensible\tmaster\t3333333333333333333333333333333333333333\tmaster\thttps://github.com/tpope/vim-sensible\t\n' > '${fixtureRoot}/.reqpack-cache/vim-plug/remote-info.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "git ls-remote --symref 'https://github.com/tpope/vim-sensible.git' HEAD refs/heads/* refs/tags/*", exitCode = 0, stdout = "ref: refs/heads/master\tHEAD\n3333333333333333333333333333333333333333\tHEAD\n3333333333333333333333333333333333333333\trefs/heads/master\n", stderr = "", success = true },
    { match = "git -C '${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible' rev-parse HEAD", exitCode = 0, stdout = "1111111111111111111111111111111111111111\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "vim-sensible",
    resultVersion = "master",
  },
}
