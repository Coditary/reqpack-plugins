return {
  name = "conda update all packages",
  request = {
    action = "update",
    system = "conda",
    packages = {},
  },
  fakeExec = {
    {
      match = "command -v 'conda' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "conda info --json",
      exitCode = 0,
      stdout = [[{"root_prefix":"/opt/conda"}]],
      stderr = "",
      success = true,
    },
    {
      match = "conda update --yes --json --prefix '/opt/conda' --all",
      exitCode = 0,
      stdout = [[{"success":true}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'conda' >/dev/null 2>&1",
      "conda update --yes --json --prefix '/opt/conda' --all"
    },
    events = { "updated", "success" },
  }
}
