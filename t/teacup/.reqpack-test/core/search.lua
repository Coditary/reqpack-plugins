return {
  name = "teacup search uses list prompt",
  request = {
    action = "search",
    system = "teacup",
    prompt = "Tclx",
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup list 'Tclx'", exitCode = 0, stdout = "entity name version platform\n------- ---- ------- --------\npackage Tclx 8.4 win32-ix86\npackage Tclx 8.4 linux-glibc2.3-ix86\n2 entities found\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "Tclx",
    resultVersion = "8.4",
  },
}
