return {
  name = "mojo install local unsupported",
  request = {
    action = "install",
    system = "mojo",
    localPath = "/tmp/mojo.mojopkg",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "modular mojo local installs are not supported",
      unavailable = "{path=/tmp/mojo.mojopkg, reason=local-install-unsupported}",
    },
  },
}
