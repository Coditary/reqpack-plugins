return {
  name = "snap install devmode package",
  request = {
    action = "install",
    system = "snap",
    packages = {
      { name = "mypkg", flags = { "devmode" } }
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
      match = "snap install 'mypkg' --devmode",
      exitCode = 0,
      stdout = "mypkg installed\n",
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
