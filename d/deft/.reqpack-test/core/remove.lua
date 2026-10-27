return {
  name = "deft remove cached package",
  request = {
    action = "remove",
    system = "deft",
    packages = {
      { name = "strings" }
    },
  },
  fixtureDirs = {
    ".local/state/dylan/_packages/strings/1.1.0/src",
  },
  fixtureFiles = {
    {
      path = ".local/state/dylan/_packages/strings/1.1.0/src/dylan-package.json",
      content = [[{"name":"strings","version":"1.1.0","description":"String helpers"}]],
    },
  },
  fakeExec = {
    { match = "test -d '.local/state/dylan/_packages'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "ls -1A '.local/state/dylan/_packages'", exitCode = 0, stdout = "strings\n", stderr = "", success = true },
    { match = "ls -1A '.local/state/dylan/_packages/strings'", exitCode = 0, stdout = "1.1.0\n", stderr = "", success = true },
    { match = "test -f '.local/state/dylan/_packages/strings/1.1.0/src/dylan-package.json'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cat '.local/state/dylan/_packages/strings/1.1.0/src/dylan-package.json'", exitCode = 0, stdout = [[{"name":"strings","version":"1.1.0","description":"String helpers"}]], stderr = "", success = true },
    { match = "rm -rf '.local/state/dylan/_packages/strings/1.1.0'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    commands = {
      "test -d '.local/state/dylan/_packages'",
      "ls -1A '.local/state/dylan/_packages/strings'"
    },
  },
}
