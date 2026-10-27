return {
  name = "smlpkg search unsupported",
  request = {
    action = "search",
    system = "smlpkg",
    prompt = "random",
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 0,
  },
}
