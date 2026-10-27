return {
  name = "zinit install bootstraps manager",
  request = {
    action = "install",
    system = "zinit",
    flags = {
      "data-root=${fixtureRoot}/data",
      "cache-root=${fixtureRoot}/cache",
    },
    packages = {
      { name = "zsh-users/zsh-completions" },
    },
  },
  fakeExec = {
    {
      match = "mkdir -p '${fixtureRoot}/data' '${fixtureRoot}/cache' '${fixtureRoot}/data/home' '${fixtureRoot}/data/home/plugins' '${fixtureRoot}/data/home/snippets' '${fixtureRoot}/data/home/completions' '${fixtureRoot}/data/home/polaris'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -f '${fixtureRoot}/data/home/zinit.git/zinit.zsh'",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data/home' && git clone --depth=1 'https://github.com/zdharma-continuum/zinit.git' '${fixtureRoot}/data/home/zinit.git'",
      exitCode = 0,
      stdout = "cloning\n",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/data/packages.tsv'",
      exitCode = 1,
      stdout = "",
      stderr = "missing\n",
      success = false,
    },
    {
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit load '\''zsh-users/zsh-completions'\''']],
      exitCode = 0,
      stdout = "Loaded\n",
      stderr = "",
      success = true,
    },
    {
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit cd '\''zsh-users/zsh-completions'\'' >/dev/null 2>&1; pwd']],
      exitCode = 0,
      stdout = "${fixtureRoot}/data/home/plugins/zsh-users---zsh-completions\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' && printf %s 'zsh-users/zsh-completions\tzsh-users/zsh-completions\tzsh-users/zsh-completions\tload\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-completions\tzsh-users/zsh-completions\t\n' > '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '${fixtureRoot}/data' && printf %s '# Managed by ReqPack zinit plugin
zinit load '\''zsh-users/zsh-completions'\''
' > '${fixtureRoot}/data/packages.zsh']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/data/home/plugins/zsh-users---zsh-completions'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-completions' rev-parse HEAD",
      exitCode = 0,
      stdout = "2222222222222222222222222222222222222222\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-completions' ls-remote origin HEAD",
      exitCode = 0,
      stdout = "2222222222222222222222222222222222222222\tHEAD\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
