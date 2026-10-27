return {
  name = "zplug remove package and rewrite loadfile",
  fixtureRoot = "/home/test",
  request = {
    action = "remove",
    system = "zplug",
    packages = {
      { action = "remove", name = "zsh-users/zsh-autosuggestions" },
    },
  },
  fixtureDirs = {
    ".zplug",
  },
  fixtureFiles = {
    { path = ".zplug/init.zsh", content = "# fake zplug\n" },
    { path = ".zplug/packages.zsh", content = "zplug \"zsh-users/zsh-autosuggestions\", as:plugin, frozen:true\nzplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n" },
  },
  fakeExec = {
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "zplug \"zsh-users/zsh-autosuggestions\", as:plugin, frozen:true\nzplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug clean --force "zsh-users/zsh-autosuggestions"']], exitCode = 0, stdout = "Removed\n", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug' && printf %s 'zplug \"junegunn/fzf\", as:command, use:bin/fzf, at:v0.58.0\n' > '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      "cat '/home/test/.zplug/packages.zsh'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug clean --force "zsh-users/zsh-autosuggestions"']],
      "mkdir -p '/home/test/.zplug' && printf %s 'zplug \"junegunn/fzf\", as:command, use:bin/fzf, at:v0.58.0\n' > '/home/test/.zplug/packages.zsh'",
    },
    events = { "deleted", "success" },
  },
}
