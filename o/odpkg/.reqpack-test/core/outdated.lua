return {
  name = "odpkg outdated returns empty",
  request = {
    action = "outdated",
    system = "odpkg",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
