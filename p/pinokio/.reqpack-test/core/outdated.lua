return {
  name = "pinokio outdated empty",
  request = {
    action = "outdated",
    system = "pinokio",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
