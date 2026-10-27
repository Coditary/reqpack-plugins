return {
  name = "mamba update all packages",
  request = {
    action = "update",
    system = "mamba",
    packages = {},
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
      match = "mamba update --yes --json --prefix '/' --all",
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
      "mamba update --yes --json --prefix '/' --all"
    },
    events = { "updated", "success" },
  }
}
