return {
  name = "smlpkg update all requirements",
  request = {
    action = "update",
    system = "smlpkg",
    packages = {
      { action = "update", name = "github.com/diku-dk/sml-random" }
    },
  },
  fakeExec = {
    { match = "command -v smlpkg >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg upgrade", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "smlpkg sync", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "<lua-value>",
      success = "ok",
    },
  },
}
