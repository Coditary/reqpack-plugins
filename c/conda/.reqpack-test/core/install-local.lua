return {
  name = "conda install local spec file",
  request = {
    action = "install",
    system = "conda",
    localPath = "/tmp/environment.yml",
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
      match = "conda install --yes --json --prefix '/opt/conda' --file '/tmp/environment.yml'",
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
      "conda install --yes --json --prefix '/opt/conda' --file '/tmp/environment.yml'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/environment.yml}",
    },
  }
}
