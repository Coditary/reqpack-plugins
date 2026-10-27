return {
  name = "raco update package",
  request = {
    action = "update",
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
      match = "raco pkg update --batch --scope user --deps search-auto 'shell-completion'",
      exitCode = 0,
      stdout = "Updating shell-completion\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
