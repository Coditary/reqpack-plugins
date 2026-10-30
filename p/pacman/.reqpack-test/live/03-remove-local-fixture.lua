return {
  name = "live remove offline fixture pacman",
  request = {
    action = "remove",
    system = "pacman",
    packages = {
      { name = "reqpack-live-fixture" },
    },
  },
  expect = {
    success = true,
  },
}
