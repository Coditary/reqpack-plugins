return {
  name = "raco install local archive",
  request = {
    action = "install",
    system = "raco",
    localPath = "/tmp/pkg.zip",
  },
  fixtureDirs = {
    "/tmp"
  },
  fixtureFiles = {
    ["/tmp/pkg.zip"] = "zip-bytes"
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
      match = "raco pkg install --batch --scope user --deps search-auto '/tmp/pkg.zip'",
      exitCode = 0,
      stdout = "Installing from archive\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
