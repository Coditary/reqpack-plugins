return {
  name = "npm outdated global packages",
  request = {
    action = "outdated",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" NPM_CONFIG_PREFIX=\"$HOME/.local\" NPM_CONFIG_CACHE=\"$HOME/.npm\" NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_PROGRESS=false NPM_CONFIG_LOGLEVEL=error npm outdated -g --depth=0 --json",
      exitCode = 1,
      stdout = [[{"typescript":{"current":"5.8.2","wanted":"5.8.3","latest":"5.9.0","location":"/home/test/.local/lib/node_modules/typescript"}}]],
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" NPM_CONFIG_PREFIX=\"$HOME/.local\" NPM_CONFIG_CACHE=\"$HOME/.npm\" NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_PROGRESS=false NPM_CONFIG_LOGLEVEL=error npm outdated -g --depth=0 --json"
    },
    resultCount = 1,
    resultName = "typescript",
    resultVersion = "5.8.2",
    events = { "outdated" },
  }
}
