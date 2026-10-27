return {
  name = "deft update package and workspace",
  request = {
    action = "update",
    system = "deft",
    packages = {
      { name = "json" }
    },
  },
  fakeExec = {
    { match = "deft install json", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
    { match = "deft update", exitCode = 0, stdout = "updated\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = { "deft install json", "deft update" },
    events = { "updated", "success" },
  },
}
