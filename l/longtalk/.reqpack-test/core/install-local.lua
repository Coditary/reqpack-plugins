return {
  name = "longtalk installLocal unsupported",
  request = {
    action = "install",
    system = "longtalk",
    localPath = "/tmp/example-pack",
  },
  expect = {
    success = false,
    events = { "failed" },
  },
}
