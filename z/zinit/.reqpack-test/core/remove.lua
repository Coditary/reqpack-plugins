return {
  name = "zinit remove managed plugin",
  request = {
    action = "remove",
    system = "zinit",
    flags = {
      "data-root=${fixtureRoot}/data",
      "cache-root=${fixtureRoot}/cache",
    },
    packages = {
      { name = "zsh-users/zsh-autosuggestions" },
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
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit delete '\''zsh-users/zsh-autosuggestions'\''']],
      exitCode = 0,
      stdout = "deleted\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' && printf %s '' > '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' && printf %s '# Managed by ReqPack zinit plugin\n' > '${fixtureRoot}/data/packages.zsh'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions' rev-parse HEAD",
      exitCode = 1,
      stdout = "",
      stderr = "fatal\n",
      success = false,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions' ls-remote origin HEAD",
      exitCode = 1,
      stdout = "",
      stderr = "fatal\n",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
