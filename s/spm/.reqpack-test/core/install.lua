return {
  name = "spm install registry skill",
  request = {
    action = "install",
    system = "spm",
    packages = {
      { name = "@github/polyglot-test-agent", version = "1.0.0" }
    }
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
      match = "spm install --json @github/polyglot-test-agent@1.0.0",
      exitCode = 0,
      stdout = [[{"command":"install","status":"success","skills":[{"name":"@github/polyglot-test-agent","version":"1.0.0","linked_agents":["Claude Code","Cursor"]}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "spm install --json @github/polyglot-test-agent@1.0.0"
    },
    events = { "installed", "success" },
  }
}
