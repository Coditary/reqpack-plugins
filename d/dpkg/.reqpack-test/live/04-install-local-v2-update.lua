return {
  name = "live install offline fixture v2",
  request = {
    action = "install",
    system = "dpkg",
    localPath = "/workspace/live-fixtures/debian/reqpack-live-fixture_2.0_all.deb",
  },
  expect = {
    success = true,
  },
}
