return {
  name = "spago upgrade workspace",
  request = {
    action = "update",
    system = "spago",
    packages = {
      { name = "prelude" },
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
      match = "spago upgrade",
      exitCode = 0,
      stdout = "upgraded\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
