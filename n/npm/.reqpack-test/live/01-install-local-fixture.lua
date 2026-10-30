return {
  name = "live install offline fixture npm tarball",
  request = {
    action = "installLocal",
    system = "npm",
    localPath = "/workspace/live-fixtures/npm/reqpack-live-fixture-1.0.0.tgz",
  },
  expect = {
    success = true,
  },
}
