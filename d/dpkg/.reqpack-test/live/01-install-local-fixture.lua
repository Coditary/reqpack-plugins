return {
  name = "live install offline fixture deb",
  request = {
    action = "install",
    system = "dpkg",
    localPath = "/workspace/live-fixtures/debian/reqpack-live-fixture_1.0_all.deb",
  },
  expect = {
    success = true,
  },
}
