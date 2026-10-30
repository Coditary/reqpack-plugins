return {
  name = "live list installed hello",
  request = {
    action = "list",
    system = "nix",
    packages = {
      { name = "hello" },
    },
  },
  expect = {
    success = true,
    minItems = 1,
    containsName = "hello",
  },
}
