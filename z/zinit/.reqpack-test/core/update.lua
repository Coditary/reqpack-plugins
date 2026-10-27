return {
  name = "zinit update managed plugin",
  request = {
    action = "update",
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
      match = "test -f '${fixtureRoot}/data/home/zinit.git/zinit.zsh'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/data/packages.tsv'",
      exitCode = 0,
      stdout = "zsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tlight\tplugin\t${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions\tzsh-users/zsh-autosuggestions\tdepth=1\n",
      stderr = "",
      success = true,
    },
    {
      match = [[zsh -lc 'export LC_ALL=C; export LANG=C; export LANGUAGE=C; export NO_COLOR=1; export TERM=dumb; export PAGER=cat; typeset -gA ZINIT; ZINIT[HOME_DIR]='\''${fixtureRoot}/data/home'\''; ZINIT[BIN_DIR]='\''${fixtureRoot}/data/home/zinit.git'\''; ZINIT[PLUGINS_DIR]='\''${fixtureRoot}/data/home/plugins'\''; ZINIT[SNIPPETS_DIR]='\''${fixtureRoot}/data/home/snippets'\''; ZINIT[COMPLETIONS_DIR]='\''${fixtureRoot}/data/home/completions'\''; ZINIT[ZCOMPDUMP_PATH]='\''${fixtureRoot}/cache/zcompdump'\''; ZINIT[ZPFX]='\''${fixtureRoot}/data/home/polaris'\''; ZPFX="$ZINIT[ZPFX]"; source "$ZINIT[BIN_DIR]/zinit.zsh" >/dev/null 2>&1 || exit 1; zinit update '\''zsh-users/zsh-autosuggestions'\''']],
      exitCode = 0,
      stdout = "updated\n",
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
      stdout = "3333333333333333333333333333333333333333\n",
      stderr = "",
      success = true,
    },
    {
      match = "git -C '${fixtureRoot}/data/home/plugins/zsh-users---zsh-autosuggestions' ls-remote origin HEAD",
      exitCode = 0,
      stdout = "3333333333333333333333333333333333333333\tHEAD\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
