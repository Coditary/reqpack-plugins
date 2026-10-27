return {
  name = "snap install local artifact",
  request = {
    action = "install",
    system = "snap",
    localPath = "/tmp/test.snap",
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
      match = "snap install '/tmp/test.snap' --dangerous",
      exitCode = 0,
      stdout = "test installed\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/test.snap}",
      success = "ok",
    },
  }
}
