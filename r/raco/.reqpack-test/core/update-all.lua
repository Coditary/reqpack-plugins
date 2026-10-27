return {
  name = "raco update all packages",
  request = {
    action = "update",
    system = "raco",
    packages = {},
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
      match = "raco pkg update --batch --scope user --deps search-auto --all",
      exitCode = 0,
      stdout = "Updating all packages\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
