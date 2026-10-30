return {
  name = "live remove hello from profile",
  request = {
    action = "remove",
    system = "nix",
    packages = {
      { name = "hello" },
    },
  },
  expect = {
    success = true,
  },
}
