return {
  name = "zig search url prompt",
  request = {
    action = "search",
    system = "zig",
    prompt = "https://example.com/demo.tar.gz",
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "demo",
    events = { "searched" },
  }
}
