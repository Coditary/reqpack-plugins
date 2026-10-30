return {
  name = "live install hello from nixpkgs",
  request = {
    action = "install",
    system = "nix",
    packages = {
      { name = "hello" },
    },
  },
  expect = {
    success = true,
  },
}
