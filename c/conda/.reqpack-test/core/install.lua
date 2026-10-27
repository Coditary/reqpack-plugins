return {
  name = "conda install package",
  request = {
    action = "install",
    system = "conda",
    packages = {
      { action = "install", name = "python", version = "3.12" }
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
      match = "conda list --json --prefix '/opt/conda'",
      exitCode = 0,
      stdout = "[]",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'conda' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "conda install --yes --json --prefix '/opt/conda' 'python=3.12'",
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
      "conda install --yes --json --prefix '/opt/conda' 'python=3.12'",
    },
    events = { "installed", "success" },
  }
}
