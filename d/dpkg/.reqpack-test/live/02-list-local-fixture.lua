return {
  name = "live list installed offline fixture",
  request = {
    action = "list",
    system = "dpkg",
    packages = {
      { name = "reqpack-live-fixture" },
    },
  },
  expect = {
    success = true,
    minItems = 1,
    containsName = "reqpack-live-fixture",
  },
}
