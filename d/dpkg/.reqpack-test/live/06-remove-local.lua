return {
  name = "live remove offline fixture",
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
