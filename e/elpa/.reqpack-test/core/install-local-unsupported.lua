return {
  name = "elpa install local unsupported",
  request = {
    action = "install",
    system = "elpa",
    localPath = "/tmp/use-package.tar.gz",
  },
  fakeExec = {
    {
      match = "command -v 'emacs' >/dev/null 2>&1",
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
      failed = "installLocal only supports .el or .tar packages",
      unavailable = "{path=/tmp/use-package.tar.gz, reason=local-install-unsupported}",
    },
  }
}
