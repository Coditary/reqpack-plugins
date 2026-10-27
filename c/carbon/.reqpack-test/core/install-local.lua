return {
  name = "carbon install local unsupported",
  request = {
    action = "install",
    system = "carbon",
    localPath = "/tmp/carbon-package.tgz",
  },
  fakeExec = {
    {
      match = "command -v 'carbon' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "carbon installLocal is not supported; Carbon installs packages from Docker image references",
      unavailable = "{path=/tmp/carbon-package.tgz, reason=local-install-unsupported}",
    },
  }
}
