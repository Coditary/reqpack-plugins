return {
  name = "raco remove package",
  request = {
    action = "remove",
    system = "raco",
    packages = {
      { name = "shell-completion" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'raco' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg remove --batch --scope user 'shell-completion'",
      exitCode = 0,
      stdout = "Removing shell-completion\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
