return {
  name = "paru list",
  request = {
    action = "list",
    system = "paru",
  },
  fakeExec = {
    {
      match = "command -v paru >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" AURDEST=\"$HOME/.cache/paru\" paru -Q",
      exitCode = 0,
      stdout = "ripgrep 14.1.0-1\nfd 9.0.0-1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "ripgrep",
    resultVersion = "14.1.0-1",
  }
}
