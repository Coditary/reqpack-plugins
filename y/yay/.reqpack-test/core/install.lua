return {
  name = "yay install",
  request = {
    action = "install",
    system = "yay",
    packages = {
      { name = "ripgrep" }
    },
  },
  fakeExec = {
    {
      match = "command -v yay >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME='$HOME' XDG_CONFIG_HOME='$HOME/.config' XDG_CACHE_HOME='$HOME/.cache' XDG_DATA_HOME='$HOME/.local/share' AURDEST='$HOME/.cache/yay' yay -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None --noremovemake ripgrep",
      exitCode = 0,
      stdout = "install ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME='$HOME' XDG_CONFIG_HOME='$HOME/.config' XDG_CACHE_HOME='$HOME/.cache' XDG_DATA_HOME='$HOME/.local/share' AURDEST='$HOME/.cache/yay' yay -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None --noremovemake ripgrep"
    },
    stdout = {
      "install ok\n"
    },
    events = { "installed", "success" },
  }
}
