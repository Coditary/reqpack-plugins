return {
  name = "live bootstrap nix then search hello",
  request = {
    action = "search",
    system = "nix",
    prompt = "hello",
  },
  expect = {
    success = true,
    minItems = 1,
    containsName = "hello",
  },
}
