return {
  name = "smlpkg install exact package",
  request = {
    action = "install",
    system = "smlpkg",
    packages = {
      { name = "github.com/diku-dk/sml-random", version = "1.2.3" }
    },
  },
  fakeExec = {
    { match = "command -v smlpkg >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg add 'github.com/diku-dk/sml-random' '1.2.3'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg sync", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    commands = {
      "command -v smlpkg >/dev/null 2>&1",
      "smlpkg add 'github.com/diku-dk/sml-random' '1.2.3'",
      "smlpkg sync",
    },
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  },
}
