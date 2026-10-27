return {
  name = "deft list installed",
  request = {
    action = "list",
    system = "deft",
  },
  fixtureDirs = {
    ".local/state/dylan/_packages/strings/1.1.0/src",
  },
  fixtureFiles = {
    {
      path = ".local/state/dylan/_packages/strings/1.1.0/src/dylan-package.json",
      content = [[{"name":"strings","version":"1.1.0","description":"String helpers","url":"https://github.com/dylan-lang/strings","license":"MIT","keywords":["text","strings"]}]],
    },
  },
  fakeExec = {
    { match = "deft list", exitCode = 0, stdout = "     Inst.   Latest  Name      Description\n     1.1.0    1.1.0   strings   String helpers\n", stderr = "", success = true },
    { match = "test -d '.local/state/dylan/_packages'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ls -1A '.local/state/dylan/_packages'", exitCode = 0, stdout = "strings\n", stderr = "", success = true },
    { match = "ls -1A '.local/state/dylan/_packages/strings'", exitCode = 0, stdout = "1.1.0\n", stderr = "", success = true },
    { match = "test -f '.local/state/dylan/_packages/strings/1.1.0/src/dylan-package.json'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '.local/state/dylan/_packages/strings/1.1.0/src/dylan-package.json'", exitCode = 0, stdout = [[{"name":"strings","version":"1.1.0","description":"String helpers","url":"https://github.com/dylan-lang/strings","license":"MIT","keywords":["text","strings"]}]], stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
  },
}
