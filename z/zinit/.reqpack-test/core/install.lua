return {
  name = "zinit install plugin with flags",
  request = {
    action = "install",
    system = "zinit",
    flags = {
      "data-root=${fixtureRoot}/data",
      "cache-root=${fixtureRoot}/cache",
      "light-mode",
      "depth=1",
    },
    packages = {
      { name = "zsh-users/zsh-autosuggestions" },
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
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit ice depth"1"; zinit light '\''zsh-users/zsh-autosuggestions'\''']],
      exitCode = 0,
      stdout = "Loaded\n",
      stderr = "",
      success = true,
    },
    {
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit cd '\''zsh-users/zsh-autosuggestions'\'' >/dev/null 2>&1; pwd']],
      exitCode = 0,
      stdout = "${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' && printf %s 'zsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tlight\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tdepth=1\n' > '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '${fixtureRoot}/data' && printf %s '# Managed by ReqPack zinit plugin
zinit ice depth"1"
zinit light '\''zsh-users/zsh-autosuggestions'\''
' > '${fixtureRoot}/data/packages.zsh']],
      exitCode = 0,
      stdout = "",
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
      stdout = "1111111111111111111111111111111111111111\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions' ls-remote origin HEAD",
      exitCode = 0,
      stdout = "1111111111111111111111111111111111111111\tHEAD\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    result = true,
  },
}
