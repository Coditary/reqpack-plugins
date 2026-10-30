return {
  name = "live list installed offline fixture pacman",
  request = {
    action = "list",
    system = "pacman",
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
