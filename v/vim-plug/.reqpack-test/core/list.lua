return {
  name = "vim-plug list installed and declared plugins",
  request = {
    action = "list",
    system = "vim-plug",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
  },
  fixtureDirs = {
    ".reqpack-data/vim-plug",
    ".reqpack-cache/vim-plug",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/vim-plug/manifest.tsv",
      content = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\njunegunn/fzf\tfzf\tremote\tjunegunn/fzf\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/fzf\n",
    },
    {
      path = ".reqpack-data/vim-plug/state.tsv",
      content = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\tmaster\t1111111111111111111111111111111111111111\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\tinstalled\n",
    },
    {
      path = ".reqpack-cache/vim-plug/remote-info.tsv",
      content = "junegunn/fzf\tfzf\tjunegunn/fzf\tmaster\t9999999999999999999999999999999999999999\tmaster\thttps://github.com/junegunn/fzf\tv0.1.0\n",
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/vim-plug/manifest.tsv'", exitCode = 0, stdout = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\njunegunn/fzf\tfzf\tremote\tjunegunn/fzf\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/fzf\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/vim-plug/state.tsv'", exitCode = 0, stdout = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\tmaster\t1111111111111111111111111111111111111111\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\tinstalled\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-cache/vim-plug/remote-info.tsv'", exitCode = 0, stdout = "junegunn/fzf\tfzf\tjunegunn/fzf\tmaster\t9999999999999999999999999999999999999999\tmaster\thttps://github.com/junegunn/fzf\tv0.1.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "fzf",
    resultVersion = "master",
  },
}
