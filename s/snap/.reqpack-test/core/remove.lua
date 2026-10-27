return {
  name = "snap remove",
  request = {
    action = "remove",
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
      match = "snap remove 'hello-world'",
      exitCode = 0,
      stdout = "hello-world removed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
