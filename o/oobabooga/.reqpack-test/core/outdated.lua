return {
  name = "oobabooga outdated empty",
  request = {
    action = "outdated",
    system = "oobabooga",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
