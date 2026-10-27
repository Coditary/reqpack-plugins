return {
  name = "deft install local unsupported",
  request = {
    action = "install",
    system = "deft",
    localPath = "/tmp/demo-package",
  },
  fakeExec = {
    { match = "command -v 'deft' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "deft installLocal is not supported; use published catalog packages",
      unavailable = "{path=/tmp/demo-package, reason=local-install-unsupported}",
    },
  },
}
