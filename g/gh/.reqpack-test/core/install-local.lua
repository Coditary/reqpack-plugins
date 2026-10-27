return {
  name = "gh installLocal unsupported",
  request = {
    action = "install",
    system = "gh",
    localPath = "/tmp/gh-local",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "gh plugin does not support installLocal()",
      unavailable = "{path=/tmp/gh-local, reason=local-install-unsupported}",
    },
  }
}
