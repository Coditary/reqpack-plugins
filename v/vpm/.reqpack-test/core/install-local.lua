return {
  name = "vpm install local unsupported",
  request = {
    action = "install",
    system = "vpm",
    localPath = "/tmp/local-module",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "vpm local installs are not supported",
      unavailable = "{path=/tmp/local-module, reason=local-install-unsupported}",
    },
  }
}
