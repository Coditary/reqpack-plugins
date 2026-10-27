return {
  name = "zplug install bootstraps and installs package",
  fixtureRoot = "/home/test",
  request = {
    action = "install",
    system = "zplug",
    packages = {
      {
        action = "install",
        name = "zsh-users/zsh-autosuggestions",
        flags = { "as=plugin", "frozen" },
      },
    },
  },
  fakeExec = {
    { match = "command -v 'zsh' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/home/test/.zplug/init.zsh'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "command -v 'git' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "git clone --depth 1 'https://github.com/zplug/zplug' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '/home/test/.zplug/packages.zsh'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "mkdir -p '/home/test/.zplug' && printf %s 'zplug \"zsh-users/zsh-autosuggestions\"\n' > '/home/test/.zplug/packages.zsh'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug install "zsh-users/zsh-autosuggestions"']], exitCode = 0, stdout = "Installed\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'zsh' >/dev/null 2>&1",
      "test -f '/home/test/.zplug/init.zsh'",
      "command -v 'git' >/dev/null 2>&1",
      "mkdir -p '/home/test'",
      "git clone --depth 1 'https://github.com/zplug/zplug' '/home/test/.zplug'",
      "mkdir -p '/home/test/.zplug/cache' '/home/test/.zplug'",
      "cat '/home/test/.zplug/packages.zsh'",
      "mkdir -p '/home/test/.zplug' && printf %s 'zplug \"zsh-users/zsh-autosuggestions\"\n' > '/home/test/.zplug/packages.zsh'",
      [[LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' ZPLUG_HOME='/home/test/.zplug' ZPLUG_CACHE_DIR='/home/test/.zplug/cache' ZPLUG_LOADFILE='/home/test/.zplug/packages.zsh' 'zsh' -lc 'source "$ZPLUG_HOME/init.zsh" >/dev/null 2>&1; zplug install "zsh-users/zsh-autosuggestions"']],
    },
    events = { "installed", "success" },
  },
}
