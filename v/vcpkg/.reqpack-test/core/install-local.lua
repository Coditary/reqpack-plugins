return {
  name = "vcpkg local install unsupported",
  request = {
    action = "install",
    system = "vcpkg",
    localPath = "/tmp/example.zip",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "vcpkg local installs are not supported",
      unavailable = "{path=/tmp/example.zip, reason=local-install-unsupported}",
    },
  }
}
