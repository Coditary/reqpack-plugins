return {
  name = "kxi outdated returns empty",
  request = {
    action = "outdated",
    system = "kxi",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
