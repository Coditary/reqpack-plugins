return {
  name = "teacup remove fully qualified package",
  request = {
    action = "remove",
    system = "teacup",
    packages = {
      { action = "remove", name = "sqlite3", version = "3.6.17" }
    },
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/home/test/.cache/reqpack/teacup/repository' || teacup create '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup remove --at '/home/test/.cache/reqpack/teacup/repository' 'sqlite3' '3.6.17'", exitCode = 0, stdout = "Removing instance package sqlite3 3.6.17 linux-glibc2.3-ix86\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  },
}
