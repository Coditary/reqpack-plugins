return {
  name = "paru remove",
  request = {
    action = "remove",
    system = "paru",
    packages = {
      { name = "ripgrep" }
    },
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" AURDEST=\"$HOME/.cache/paru\" paru -R --noconfirm ripgrep",
      exitCode = 0,
      stdout = "remove ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" AURDEST=\"$HOME/.cache/paru\" paru -R --noconfirm ripgrep"
    },
    stdout = {
      "remove ok\n"
    },
    events = { "deleted", "success" },
  }
}
