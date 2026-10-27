return {
  name = "gh list extensions",
  request = {
    action = "list",
    system = "gh",
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
      stdout = "gh codeql  github/gh-codeql  v1.2.3\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 3,
    resultName = "app:gh",
    resultVersion = "2.90.0",
  }
}
