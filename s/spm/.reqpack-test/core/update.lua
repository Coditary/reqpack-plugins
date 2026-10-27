return {
  name = "spm update no-op success",
  request = {
    action = "update",
    system = "spm",
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
      match = "spm update --json",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "spm update --json"
    },
    events = { "updated", "success" },
  }
}
