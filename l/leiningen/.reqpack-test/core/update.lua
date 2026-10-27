return {
  name = "leiningen update unsupported",
  request = {
    action = "update",
    system = "leiningen",
    packages = {
      { name = "ring/ring-json", version = "0.5.1" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'lein' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "leiningen update is not supported for arbitrary artifacts",
      unavailable = "{reason=update-unsupported}",
    },
  },
}
