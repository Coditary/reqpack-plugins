return {
  name = "zinit search managed manifest",
  request = {
    action = "search",
    system = "zinit",
    prompt = "git",
    flags = {
      "data-root=${fixtureRoot}/data",
      "cache-root=${fixtureRoot}/cache",
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/data",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/data/packages.tsv",
      content = "zsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tlight\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tdepth=1\nOMZP::git\tOMZP::git\tOMZP::git\tsnippet\tsnippet\t${fixtureRoot}/data/home/snippets/OMZP::git/OMZP::git\tOMZP::git\tsnippet,svn\n",
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "zsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tlight\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tdepth=1\nOMZP::git\tOMZP::git\tOMZP::git\tsnippet\tsnippet\t${fixtureRoot}/data/home/snippets/OMZP::git/OMZP::git\tOMZP::git\tsnippet,svn\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/data/home/snippets/OMZP::git/OMZP::git'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "OMZP::git",
  },
}
