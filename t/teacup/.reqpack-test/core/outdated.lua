return {
  name = "teacup outdated via newer filter",
  request = {
    action = "outdated",
    system = "teacup",
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/home/test/.cache/reqpack/teacup/repository' || teacup create '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup list --only newer --at '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "entity name version platform\n------- ---- ------- --------\npackage sqlite3 3.7.2 linux-glibc2.3-ix86\n1 entity found\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "sqlite3",
    resultVersion = "3.7.2",
  },
}
