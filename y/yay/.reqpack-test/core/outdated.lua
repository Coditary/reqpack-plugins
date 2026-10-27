return {
  name = "yay outdated",
  request = {
    action = "outdated",
    system = "yay",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME='$HOME' XDG_CONFIG_HOME='$HOME/.config' XDG_CACHE_HOME='$HOME/.cache' XDG_DATA_HOME='$HOME/.local/share' AURDEST='$HOME/.cache/yay' yay -Qu",
      exitCode = 0,
      stdout = "ripgrep 14.0.3-1 -> 14.1.0-1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "ripgrep",
    resultVersion = "14.0.3-1",
  }
}
