return {
  name = "yay update system",
  request = {
    action = "update",
    system = "yay",
    packages = {},
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME='$HOME' XDG_CONFIG_HOME='$HOME/.config' XDG_CACHE_HOME='$HOME/.cache' XDG_DATA_HOME='$HOME/.local/share' AURDEST='$HOME/.cache/yay' yay -Syu --noconfirm --answerclean None --answerdiff None --answeredit None --answerupgrade All --noremovemake",
      exitCode = 0,
      stdout = "system update ok\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME='$HOME' XDG_CONFIG_HOME='$HOME/.config' XDG_CACHE_HOME='$HOME/.cache' XDG_DATA_HOME='$HOME/.local/share' AURDEST='$HOME/.cache/yay' yay -Syu --noconfirm --answerclean None --answerdiff None --answeredit None --answerupgrade All --noremovemake"
    },
    stdout = {
      "system update ok\n"
    },
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{scope=system}",
      success = "ok",
    },
  }
}
