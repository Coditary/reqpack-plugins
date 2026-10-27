return {
  name = "zinit install local plugin dir",
  request = {
    action = "install",
    system = "zinit",
    flags = {
      "data-root=${fixtureRoot}/data",
      "cache-root=${fixtureRoot}/cache",
      "light-mode",
    },
    localPath = "${fixtureRoot}/local/demo-plugin",
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
      match = "test -d '${fixtureRoot}/local/demo-plugin'",
      exitCode = 0,
      stdout = "",
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
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit light '\''${fixtureRoot}/local/demo-plugin'\''']],
      exitCode = 0,
      stdout = "Loaded\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/data' && printf %s 'demo-plugin\t${fixtureRoot}/local/demo-plugin\t${fixtureRoot}/local/demo-plugin\tlight\tlocal-plugin\t${fixtureRoot}/local/demo-plugin\t${fixtureRoot}/local/demo-plugin\t\n' > '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [[mkdir -p '${fixtureRoot}/data' && printf %s '# Managed by ReqPack zinit plugin
zinit light '\''${fixtureRoot}/local/demo-plugin'\''
' > '${fixtureRoot}/data/packages.zsh']],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -e '${fixtureRoot}/local/demo-plugin'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
