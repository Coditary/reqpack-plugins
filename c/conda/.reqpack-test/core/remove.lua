return {
  name = "conda remove package",
  request = {
    action = "remove",
    system = "conda",
    packages = {
      { name = "zlib" }
    },
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
      match = "conda remove --yes --json --prefix '/opt/conda' 'zlib'",
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
      "conda remove --yes --json --prefix '/opt/conda' 'zlib'"
    },
    events = { "deleted", "success" },
  }
}
