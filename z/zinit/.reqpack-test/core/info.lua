return {
  name = "zinit info managed package",
  request = {
    action = "info",
    system = "zinit",
    prompt = "zsh-users/zsh-autosuggestions",
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
      content = "zsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tlight\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tdepth=1\n",
    },
  },
  fakeExec = {
    {
      match = "cat '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "zsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tlight\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tdepth=1\n",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions' rev-parse HEAD",
      exitCode = 0,
      stdout = "7777777777777777777777777777777777777777\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions' ls-remote origin HEAD",
      exitCode = 0,
      stdout = "7777777777777777777777777777777777777777\tHEAD\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "zsh-users/zsh-autosuggestions",
  },
}
