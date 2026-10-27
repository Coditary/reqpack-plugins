return {
  name = "raco install local directory",
  request = {
    action = "install",
    system = "raco",
    localPath = "/tmp/example-pkg",
  },
  fixtureDirs = {
    "/tmp",
    "/tmp/example-pkg"
  },
  fakeExec = {
    {
      match = "command -v 'raco' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "test -d '/tmp/example-pkg'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "raco pkg install --batch --scope user --deps search-auto --link '/tmp/example-pkg'",
      exitCode = 0,
      stdout = "Installing link\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
