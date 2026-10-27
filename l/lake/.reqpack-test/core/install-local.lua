return {
  name = "lake install local unsupported",
  request = {
    action = "install",
    system = "lake",
    localPath = "/tmp/example",
  },
  expect = {
    success = false,
    events = { "unavailable", "failed" },
  }
}
