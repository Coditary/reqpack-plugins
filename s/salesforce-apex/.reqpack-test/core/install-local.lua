return {
  name = "salesforce apex install local unsupported",
  request = {
    action = "install",
    system = "salesforce-apex",
    localPath = "/tmp/pkg.zip",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "salesforce local installs are not supported",
      unavailable = "{path=/tmp/pkg.zip, reason=local-install-unsupported}",
    },
  },
}
