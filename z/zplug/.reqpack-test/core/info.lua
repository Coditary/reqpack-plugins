return {
  name = "zplug info merges registration and upstream output",
  fixtureRoot = "/home/test",
  request = {
    action = "info",
    system = "zplug",
    prompt = "junegunn/fzf",
  },
  fixtureDirs = {
    ".zplug",
  },
  fixtureFiles = {
    { path = ".zplug/init.zsh", content = "# fake zplug\n" },
    { path = ".zplug/packages.zsh", content = "zplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n" },
  },
  fakeExec = {
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "zplug \"junegunn/fzf\", as:command, use:\"bin/fzf\", at:\"v0.58.0\"\n", stderr = "", success = true },
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug list']], exitCode = 0, stdout = "junegunn/fzf\n", stderr = "", success = true },
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug info "junegunn/fzf"']], exitCode = 0, stdout = "Package: junegunn/fzf\nURL: https://github.com/junegunn/fzf\nFrom: github\nAs: command\nUse: bin/fzf\nAt: v0.58.0\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "cat '/home/test/.zplug/packages.zsh'",
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug list']],
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug info "junegunn/fzf"']],
    },
    events = { "informed" },
    resultName = "junegunn/fzf",
    resultVersion = "v0.58.0",
  },
}
