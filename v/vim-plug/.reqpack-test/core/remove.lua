return {
  name = "vim-plug remove managed plugin",
  request = {
    action = "remove",
    system = "vim-plug",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { name = "tpope/vim-sensible" },
    },
  },
  fixtureDirs = {
    ".reqpack-data/vim-plug",
    ".reqpack-config/vim-plug",
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
    {
      path = ".reqpack-data/vim-plug/autoload/plug.vim",
      content = "loaded",
    },
  },
  fakeExec = {
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/vim-plug' '${fixtureRoot}/.reqpack-cache/vim-plug' '${fixtureRoot}/.reqpack-config/vim-plug' '${fixtureRoot}/.reqpack-data/vim-plug/autoload' '${fixtureRoot}/.reqpack-data/vim-plug/plugged' '${fixtureRoot}/.reqpack-cache/vim-plug/tmp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/vim-plug/manifest.tsv'", exitCode = 0, stdout = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\t\t\t\t\t\t\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\n", stderr = "", success = true },
    { match = "cat '${fixtureRoot}/.reqpack-data/vim-plug/state.tsv'", exitCode = 0, stdout = "tpope/vim-sensible\tvim-sensible\tremote\ttpope/vim-sensible\tmaster\t1111111111111111111111111111111111111111\t\t\t\t${fixtureRoot}/.reqpack-data/vim-plug/plugged/vim-sensible\tinstalled\n", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/vim-plug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-config/vim-plug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '' > '${fixtureRoot}/.reqpack-data/vim-plug/manifest.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s '' > '${fixtureRoot}/.reqpack-data/vim-plug/state.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/.reqpack-data/vim-plug/autoload/plug.vim'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v 'nvim' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "nvim --headless -u '${fixtureRoot}/.reqpack-config/vim-plug/reqpack.vim' -i NONE -c 'PlugClean!' -c 'qa'", exitCode = 0, stdout = "Cleaned.\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    result = true,
    events = { "deleted", "success" },
  },
}
