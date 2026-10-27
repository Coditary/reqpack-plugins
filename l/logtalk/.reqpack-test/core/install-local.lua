return {
  name = "logtalk install local unsupported",
  request = {
    action = "install",
    system = "logtalk",
    localPath = "/tmp/example-pack.tar.gz",
  },
  expect = {
    success = false,
    events = { "unavailable", "failed" },
  }
}
