return {
  name = "composer install local unsupported",
  request = {
    action = "install",
    system = "composer",
    localPath = "/tmp/package.zip",
  },
  fakeExec = {
    {
      match = "command -v 'composer' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "composer local installs are not supported in v1",
    },
  },
}
