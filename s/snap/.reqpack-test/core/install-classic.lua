return {
  name = "snap install classic package",
  request = {
    action = "install",
    system = "snap",
    packages = {
      { name = "code", flags = { "classic" } }
    },
  },
  fakeExec = {
    {
      match = "command -v 'snap' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "snap install 'code' --classic",
      exitCode = 0,
      stdout = "code installed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
