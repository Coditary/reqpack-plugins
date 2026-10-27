return {
  name = "oobabooga search app",
  request = {
    action = "search",
    system = "oobabooga",
    prompt = "oobabooga",
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "app:oobabooga",
  }
}
