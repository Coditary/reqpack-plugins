return {
  name = "spm uninstall registry skill",
  request = {
    action = "remove",
    system = "spm",
    packages = {
      { name = "@github/polyglot-test-agent" }
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
      match = "spm uninstall --json @github/polyglot-test-agent",
      exitCode = 0,
      stdout = [[{"command":"uninstall","status":"success","skills":[{"name":"@github/polyglot-test-agent","removed_from_json":true,"removed_from_lock":true,"files_deleted":false}]}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "spm uninstall --json @github/polyglot-test-agent"
    },
    events = { "deleted", "success" },
  }
}
