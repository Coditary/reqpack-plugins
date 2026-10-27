return {
  name = "teacup update repository",
  request = {
    action = "update",
    system = "teacup",
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/home/test/.cache/reqpack/teacup/repository' || teacup create '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup update --at '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "Installed 1 newer packages\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
