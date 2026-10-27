return {
  name = "ghskill install local unsupported",
  request = {
    action = "install",
    system = "ghskill",
    localPath = "/tmp/ghskill-local",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "ghskill plugin does not support installLocal()",
      unavailable = "{path=/tmp/ghskill-local, reason=local-install-unsupported}",
    },
  }
}
