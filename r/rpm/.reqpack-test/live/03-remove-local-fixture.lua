return {
  name = "live remove offline fixture rpm",
  request = {
    action = "remove",
    system = "rpm",
    packages = {
      { name = "reqpack-live-fixture" },
    },
  },
  expect = {
    success = true,
  },
}
