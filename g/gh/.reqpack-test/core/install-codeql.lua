return {
  name = "gh install codeql latest",
  request = {
    action = "install",
    system = "gh",
    packages = {
      { name = "codeql" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/gh/state",
  },
  fakeExec = {
    {
      match = "gh --version",
      exitCode = 0,
      stdout = "gh version 2.90.0 (2026-05-01)\n",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh extension list",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh extension install github/gh-codeql",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql download",
      exitCode = 0,
      stdout = "downloaded\n",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql set-version latest",
      exitCode = 0,
      stdout = "set latest\n",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql list-installed",
      exitCode = 0,
      stdout = "2.20.5\n",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql",
      exitCode = 0,
      stdout = "Current channel: release.\nCurrent version: 2.20.5.\n",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '/home/test/.cache/reqpack/gh/state'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql list-versions",
      exitCode = 0,
      stdout = "2.20.5\n2.20.4\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
