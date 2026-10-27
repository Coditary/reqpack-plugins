return {
  name = "npm list global packages",
  request = {
    action = "list",
    system = "npm",
  },
  fakeExec = {
    {
      match = "command -v npm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" NPM_CONFIG_PREFIX=\"$HOME/.local\" NPM_CONFIG_CACHE=\"$HOME/.npm\" NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_PROGRESS=false NPM_CONFIG_LOGLEVEL=error npm ls -g --depth=0 --json",
      exitCode = 0,
      stdout = [[{"name":"lib","dependencies":{"eslint":{"version":"9.18.0","path":"/home/test/.local/lib/node_modules/eslint"},"typescript":{"version":"5.8.3","path":"/home/test/.local/lib/node_modules/typescript"}}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" NPM_CONFIG_PREFIX=\"$HOME/.local\" NPM_CONFIG_CACHE=\"$HOME/.npm\" NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_PROGRESS=false NPM_CONFIG_LOGLEVEL=error npm ls -g --depth=0 --json"
    },
    resultCount = 2,
    resultName = "eslint",
    resultVersion = "9.18.0",
    events = { "listed" },
  }
}
