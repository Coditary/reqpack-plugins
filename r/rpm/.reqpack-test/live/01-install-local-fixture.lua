return {
  name = "live install offline fixture rpm",
  request = {
    action = "install",
    system = "rpm",
    localPath = "/workspace/live-fixtures/rpm/reqpack-live-fixture-1.0-1.noarch.rpm",
  },
  expect = {
    success = true,
  },
}
