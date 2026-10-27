return {
  name = "io outdated returns empty",
  request = {
    action = "outdated",
    system = "io",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
