return {
  name = "live remove offline fixture deb",
  request = {
    action = "remove",
    system = "dpkg",
    packages = {
      { name = "reqpack-live-fixture" },
    },
  },
  expect = {
    success = true,
  },
}
