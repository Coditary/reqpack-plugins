return {
  name = "gradle local install unsupported",
  request = {
    action = "install",
    system = "gradle",
    localPath = "/tmp/example.jar",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "gradle local installs are not supported",
      unavailable = "{path=/tmp/example.jar, reason=local-install-unsupported}",
    },
  }
}
