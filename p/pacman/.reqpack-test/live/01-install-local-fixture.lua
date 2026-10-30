return {
  name = "live install offline fixture pacman",
  request = {
    action = "install",
    system = "pacman",
    localPath = "/workspace/live-fixtures/arch/reqpack-live-fixture-1.0-1-any.pkg.tar.zst",
  },
  expect = {
    success = true,
  },
}
