return {
  name = "gh outdated codeql",
  request = {
    action = "outdated",
    system = "gh",
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/gh/state",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/gh/state/codeql-state.json",
      content = [[{"channel":"release","currentVersion":"2.20.4","ghCodeqlInstalled":true,"installedVersions":["2.20.4"]}]],
    },
  },
  fakeExec = {
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql list-installed",
      exitCode = 0,
      stdout = "2.20.4\n",
      stderr = "",
      success = true,
    },
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql",
      exitCode = 0,
      stdout = "Current channel: release.\nCurrent version: 2.20.4.\n",
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
    events = { "outdated" },
    resultCount = 1,
    resultName = "codeql",
  }
}
