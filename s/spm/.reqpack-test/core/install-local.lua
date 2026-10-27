return {
  name = "spm install local skill path",
  request = {
    action = "install",
    system = "spm",
    localPath = "/tmp/local-skill",
  },
  fakeExec = {
    {
      match = "command -v spm >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spm install --json --no-link /tmp/local-skill",
      exitCode = 0,
      stdout = [[{"command":"install","status":"success","skills":[{"name":"@test/local-probe","version":"0.1.0"}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "spm install --json --no-link /tmp/local-skill"
    },
    events = { "installed", "success" },
  }
}
