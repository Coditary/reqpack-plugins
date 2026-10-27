return {
  name = "mamba remove package",
  request = {
    action = "remove",
    system = "mamba",
    packages = {
      { name = "zlib" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'mamba' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mamba remove --yes --json --prefix '/' 'zlib'",
      exitCode = 0,
      stdout = [[{"success":true}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'mamba' >/dev/null 2>&1",
      "mamba remove --yes --json --prefix '/' 'zlib'"
    },
    events = { "deleted", "success" },
  }
}
