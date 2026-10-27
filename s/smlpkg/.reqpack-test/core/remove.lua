return {
  name = "smlpkg remove package",
  request = {
    action = "remove",
    system = "smlpkg",
    packages = {
      { action = "remove", name = "github.com/diku-dk/sml-random" }
    },
  },
  fakeExec = {
    { match = "command -v smlpkg >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg remove 'github.com/diku-dk/sml-random'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg sync", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  },
}
