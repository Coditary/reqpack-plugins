return {
  name = "live install rejects corrupt local archive",
  request = {
    action = "install",
    system = "dpkg",
    localPath = "/workspace/live-fixtures/corrupt/corrupt.deb",
  },
  expect = {
    success = false,
  },
}
