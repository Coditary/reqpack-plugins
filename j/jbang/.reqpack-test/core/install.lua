return {
  name = "jbang install alias app",
  request = {
    action = "install",
    system = "jbang",
    packages = {
      { action = "install", name = "gavsearch@jbangdev" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'jbang' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "jbang app list --format json",
      exitCode = 0,
      stdout = "[]",
      stderr = "",
      success = true,
    },
    {
      match = "jbang app install 'gavsearch@jbangdev'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "jbang app install 'gavsearch@jbangdev'",
    },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
