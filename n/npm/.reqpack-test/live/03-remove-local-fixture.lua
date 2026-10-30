return {
  name = "live remove offline fixture npm",
  request = {
    action = "remove",
    system = "npm",
    packages = {
      { name = "reqpack-live-fixture" },
    },
  },
  expect = {
    success = true,
  },
}
