return {
  name = "snap install",
  request = {
    action = "install",
    system = "snap",
    packages = {
      { name = "hello-world" }
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
      match = "snap install 'hello-world'",
      exitCode = 0,
      stdout = "hello-world 6.4 from Canonical installed\n",
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
