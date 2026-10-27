return {
  name = "spago install local unsupported",
  request = {
    action = "install",
    system = "spago",
    localPath = "/tmp/local-purescript-package",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "spago local installs are not supported",
      unavailable = "{path=/tmp/local-purescript-package, reason=local-install-unsupported}",
    },
  }
}
