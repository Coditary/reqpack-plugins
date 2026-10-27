return {
  name = "teacup install local archive",
  request = {
    action = "install",
    system = "teacup",
    localPath = "/tmp/package-XOTcl-1.4.0-macosx-universal.zip",
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/home/test/.cache/reqpack/teacup/repository' || teacup create '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup install --at '/home/test/.cache/reqpack/teacup/repository' '/tmp/package-XOTcl-1.4.0-macosx-universal.zip'", exitCode = 0, stdout = "Installing from local archive\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  },
}
