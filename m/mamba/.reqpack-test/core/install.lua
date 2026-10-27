return {
  name = "mamba install package",
  request = {
    action = "install",
    system = "mamba",
    packages = {
      { action = "install", name = "python", version = "3.12" }
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
      match = "mamba list --json --prefix '/'",
      exitCode = 0,
      stdout = "[]",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'mamba' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mamba install --yes --json --prefix '/' 'python=3.12'",
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
      "mamba install --yes --json --prefix '/' 'python=3.12'",
    },
    events = { "installed", "success" },
  }
}
