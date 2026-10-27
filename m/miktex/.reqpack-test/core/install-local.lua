return {
  name = "miktex install local unsupported",
  request = {
    action = "install",
    system = "miktex",
    localPath = "/tmp/package.tar.lzma",
    path = "/tmp/package.tar.lzma",
  },
  expect = {
    success = false,
    result = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "miktex local installs are not supported",
      unavailable = "{path=/tmp/package.tar.lzma, reason=local-install-unsupported}",
    },
  },
}
