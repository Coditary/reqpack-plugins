return {
  name = "mamba install local spec file",
  request = {
    action = "install",
    system = "mamba",
    localPath = "/tmp/environment.yml",
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
      match = "mamba install --yes --json --prefix '/' --file '/tmp/environment.yml'",
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
      "mamba install --yes --json --prefix '/' --file '/tmp/environment.yml'",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/environment.yml}",
    },
  }
}
