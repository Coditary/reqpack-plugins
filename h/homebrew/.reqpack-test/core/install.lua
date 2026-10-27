return {
  name = "homebrew install formula",
  request = {
    action = "install",
    system = "homebrew",
    packages = {
      { name = "wget", version = "1.24.5" }
    },
  },
  fakeExec = {
    {
      match = "command -v brew 2>/dev/null || { [ -x /opt/homebrew/bin/brew ] && printf '%s\\n' /opt/homebrew/bin/brew; } || { [ -x /usr/local/bin/brew ] && printf '%s\\n' /usr/local/bin/brew; } || { [ -x /home/linuxbrew/.linuxbrew/bin/brew ] && printf '%s\\n' /home/linuxbrew/.linuxbrew/bin/brew; }",
      exitCode = 0,
      stdout = "/opt/homebrew/bin/brew\n",
      stderr = "",
      success = true,
    },
    {
      match = "/opt/homebrew/bin/brew info --json=v2 wget",
      exitCode = 0,
      stdout = [[{"formulae":[{"name":"wget","full_name":"wget","desc":"Internet file retriever","homepage":"https://www.gnu.org/software/wget/","tap":"homebrew/core","license":"GPL-3.0-or-later","dependencies":["libidn2"],"binaries":["wget"],"installed":[],"versions":{"stable":"1.24.5"},"outdated":false}],"casks":[]}]],
      stderr = "",
      success = true,
    },
    {
      match = "/opt/homebrew/bin/brew install wget",
      exitCode = 0,
      stdout = "==> Installing wget\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v brew 2>/dev/null || { [ -x /opt/homebrew/bin/brew ] && printf '%s\\n' /opt/homebrew/bin/brew; } || { [ -x /usr/local/bin/brew ] && printf '%s\\n' /usr/local/bin/brew; } || { [ -x /home/linuxbrew/.linuxbrew/bin/brew ] && printf '%s\\n' /home/linuxbrew/.linuxbrew/bin/brew; }",
      "/opt/homebrew/bin/brew info --json=v2 wget",
      "/opt/homebrew/bin/brew install wget",
    },
    stdout = {
      "/opt/homebrew/bin/brew\n",
      [[{"formulae":[{"name":"wget","full_name":"wget","desc":"Internet file retriever","homepage":"https://www.gnu.org/software/wget/","tap":"homebrew/core","license":"GPL-3.0-or-later","dependencies":["libidn2"],"binaries":["wget"],"installed":[],"versions":{"stable":"1.24.5"},"outdated":false}],"casks":[]}]],
      "==> Installing wget\n",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
