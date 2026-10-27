return {
  name = "zplug list installed packages",
  fixtureRoot = "/home/test",
  request = {
    action = "list",
    system = "zplug",
  },
  fixtureDirs = {
    ".zplug",
  },
  fixtureFiles = {
    { path = ".zplug/init.zsh", content = "# fake zplug\n" },
    { path = ".zplug/packages.zsh", content = "zplug \"zsh-users/zsh-autosuggestions\", as:plugin, frozen:true\nzplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n" },
  },
  fakeExec = {
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "zplug \"zsh-users/zsh-autosuggestions\", as:plugin, frozen:true\nzplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n", stderr = "", success = true },
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug list']], exitCode = 0, stdout = "zsh-users/zsh-autosuggestions\njunegunn/fzf\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "cat '/home/test/.zplug/packages.zsh'",
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug list']],
    },
    events = { "listed" },
    resultCount = 2,
    resultName = "junegunn/fzf",
    resultVersion = "v0.58.0",
  },
}
