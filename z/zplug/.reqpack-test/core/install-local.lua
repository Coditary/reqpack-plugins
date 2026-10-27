return {
  name = "zplug install local path",
  fixtureRoot = "/home/test",
  request = {
    action = "install",
    system = "zplug",
    localPath = "/home/test/plugins/demo-plugin",
  },
  fixtureDirs = {
    ".zplug",
    "plugins/demo-plugin",
  },
  fixtureFiles = {
    { path = ".zplug/init.zsh", content = "# fake zplug\n" },
  },
  fakeExec = {
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '/home/test/.zplug' && printf %s 'zplug \"/home/test/plugins/demo-plugin\", from:local\n' > '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug install "/home/test/plugins/demo-plugin"']], exitCode = 0, stdout = "Installed\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      "cat '/home/test/.zplug/packages.zsh'",
      "mkdir -p '/home/test/.zplug' && printf %s 'zplug \"/home/test/plugins/demo-plugin\", from:local\n' > '/home/test/.zplug/packages.zsh'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug install "/home/test/plugins/demo-plugin"']],
    },
    events = { "installed", "success" },
  },
}
