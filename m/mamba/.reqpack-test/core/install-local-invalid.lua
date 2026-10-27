return {
  name = "mamba reject unsupported local install",
  request = {
    action = "install",
    system = "mamba",
    localPath = "/tmp/environment.lock",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "installLocal only supports .conda, .tar.bz2, .txt, .json, .yaml, and .yml",
      unavailable = "{path=/tmp/environment.lock, reason=local-install-unsupported}",
    },
  }
}
