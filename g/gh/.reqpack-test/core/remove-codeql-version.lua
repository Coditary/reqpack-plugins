return {
  name = "gh remove codeql version",
  request = {
    action = "remove",
    system = "gh",
    packages = {
      { name = "codeql@2.20.4" }
    },
  },
  fixtureDirs = {
    "/home/test/.cache/reqpack/gh/state",
  },
  fixtureFiles = {
    {
      path = "/home/test/.cache/reqpack/gh/state/codeql-state.json",
      content = [[{"channel":"release","currentVersion":"2.20.4","ghCodeqlInstalled":true,"installedVersions":["2.20.4","2.20.3"]}]],
    },
  },
  fakeExec = {
    {
      match = "GH_CONFIG_DIR='/home/test/.cache/reqpack/gh/config' XDG_CACHE_HOME='/home/test/.cache/reqpack/gh/xdg-cache' XDG_STATE_HOME='/home/test/.cache/reqpack/gh/xdg-state' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' gh codeql cleanup 2.20.4",
      exitCode = 0,
      stdout = "cleaned\n",
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
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
