return {
  name = "live install rejects nonexistent package",
  request = {
    action = "install",
    system = "dpkg",
    packages = {
      { name = "reqpack-definitely-does-not-exist-99999" },
    },
  },
  expect = {
    success = false,
  },
}
