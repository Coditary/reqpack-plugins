return {
  name = "spago uninstall dependency",
  request = {
    action = "remove",
    system = "spago",
    packages = {
      { name = "halogen" },
    },
  },
  fakeExec = {
    {
      match = "command -v 'spago' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "spago uninstall halogen",
      exitCode = 0,
      stdout = "removed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
