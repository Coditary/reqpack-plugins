return {
  name = "teacup list installed repository contents",
  request = {
    action = "list",
    system = "teacup",
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -d '/home/test/.cache/reqpack/teacup/repository' || teacup create '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup list --at-default --at '/home/test/.cache/reqpack/teacup/repository'", exitCode = 0, stdout = "entity name version platform\n------- ---- ------- --------\npackage sqlite3 3.6.17 linux-glibc2.3-ix86\npackage Tkx 8.4 tcl\n2 entities found\n", stderr = "", success = true },
    { match = "mkdir -p '/home/test/.cache/reqpack/teacup/reqpack'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "printf %s 'entity name version platform\n------- ---- ------- --------\npackage sqlite3 3.6.17 linux-glibc2.3-ix86\npackage Tkx 8.4 tcl\n2 entities found\n' > '/home/test/.cache/reqpack/teacup/reqpack/last-list.txt'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "sqlite3",
    resultVersion = "3.6.17",
  },
}
