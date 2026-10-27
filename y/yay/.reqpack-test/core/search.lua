return {
  name = "yay search",
  request = {
    action = "search",
    system = "yay",
    prompt = "ripgrep",
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME='$HOME' XDG_CONFIG_HOME='$HOME/.config' XDG_CACHE_HOME='$HOME/.cache' XDG_DATA_HOME='$HOME/.local/share' AURDEST='$HOME/.cache/yay' yay -Ss ripgrep",
      exitCode = 0,
      stdout = "community/ripgrep 14.1.0-1 (1.7 MiB 4.3 MiB) [installed]\n    recursively search directories for regex pattern\naur/ripgrep-all 0.10.6-1 (+43 0.12)\n    ripgrep, but also search in PDFs and Office documents\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "ripgrep",
    resultVersion = "14.1.0-1",
  }
}
