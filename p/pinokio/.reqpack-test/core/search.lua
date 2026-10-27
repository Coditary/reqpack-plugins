return {
  name = "pinokio search app",
  request = {
    action = "search",
    system = "pinokio",
    prompt = "pinokio",
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "app:pinokio",
  }
}
