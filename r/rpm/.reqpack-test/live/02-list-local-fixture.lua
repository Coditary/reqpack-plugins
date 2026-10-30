return {
  name = "live list installed offline fixture rpm",
  request = {
    action = "list",
    system = "rpm",
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
