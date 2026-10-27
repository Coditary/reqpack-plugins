return {
  name = "deft install package",
  request = {
    action = "install",
    system = "deft",
    packages = {
      { name = "strings@1.1.0" }
    },
  },
  fakeExec = {
    { match = "deft install strings@1.1.0", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = { "deft install strings@1.1.0" },
    events = { "installed", "success" },
  },
}
