return {
  name = "live list installed offline fixture npm",
  request = {
    action = "list",
    system = "npm",
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
