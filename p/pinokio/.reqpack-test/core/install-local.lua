return {
  name = "pinokio install local unsupported",
  request = {
    action = "install",
    system = "pinokio",
    localPath = "/tmp/pinokio-local",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "pinokio plugin does not support installLocal()",
      unavailable = "{path=/tmp/pinokio-local, reason=local-install-unsupported}",
    },
  }
}
