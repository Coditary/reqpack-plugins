return {
  name = "jbang install local script",
  request = {
    action = "install",
    system = "jbang",
    localPath = "/tmp/hello.java",
  },
  fakeExec = {
    {
      match = "command -v 'jbang' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "jbang app install '/tmp/hello.java'",
      exitCode = 0,
      stdout = "installed\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = { "jbang app install '/tmp/hello.java'" },
    stdout = { "installed\n" },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/hello.java}",
      success = "ok",
    },
  }
}
