return {
  name = "teacup info combines describe and list",
  request = {
    action = "info",
    system = "teacup",
    prompt = "Expect",
  },
  fakeExec = {
    { match = "command -v 'teacup' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "teacup list 'Expect'", exitCode = 0, stdout = "entity name version platform\n------- ---- ------- --------\npackage Expect 5.44.1 linux-glibc2.3-x86_64\npackage Expect 5.44.1 win32-ix86\n2 entities found\n", stderr = "", success = true },
    { match = "teacup describe --all 'Expect'", exitCode = 0, stdout = "Entity Expect\nOrigin @ http://teapot.activestate.com\nSummary : Automating interactive applications\nDescription : Expect is a tool for automating interactive applications\n| such as telnet and ftp.\nLicense : Public Domain\nVersion : 5.43 5.44.1\nPlatform : linux-glibc2.3-x86_64\n| win32-ix86\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "Expect",
    resultVersion = "5.44.1",
  },
}
