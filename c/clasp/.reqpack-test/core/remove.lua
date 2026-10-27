return {
  name = "clasp remove deployment",
  request = {
    action = "remove",
    system = "clasp",
    packages = {
      { name = "deployment:dep-1" }
    },
  },
  fakeExec = {
    {
      match = "clasp delete-deployment dep-1",
      exitCode = 0,
      stdout = "Deleted deployment\n",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'clasp' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "clasp show-authorized-user --json",
      exitCode = 0,
      stdout = [[{"loggedIn":true}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
