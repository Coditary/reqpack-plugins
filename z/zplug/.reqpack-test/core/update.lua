return {
  name = "zplug update explicit package",
  fixtureRoot = "/home/test",
  request = {
    action = "update",
    system = "zplug",
    packages = {
      { action = "update", name = "junegunn/fzf" },
    },
  },
  fixtureDirs = {
    ".zplug",
  },
  fixtureFiles = {
    { path = ".zplug/init.zsh", content = "# fake zplug\n" },
    { path = ".zplug/packages.zsh", content = "zplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n" },
  },
  fakeExec = {
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "zplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug update --force "junegunn/fzf"']], exitCode = 0, stdout = "Updated\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      "cat '/home/test/.zplug/packages.zsh'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug update --force "junegunn/fzf"']],
    },
    events = { "updated", "success" },
  },
}
