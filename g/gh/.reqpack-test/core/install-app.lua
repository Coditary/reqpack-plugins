return {
  name = "gh install app",
  request = {
    action = "install",
    system = "gh",
    packages = {
      { name = "app:gh" }
    },
  },
  fakeExec = {
    {
      match = "gh --version",
      exitCode = 0,
      stdout = "gh version 2.90.0 (2026-05-01)\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "gh --version"
    },
    events = { "installed", "success" },
  }
}
