return {
  name = "clasp outdated empty",
  request = {
    action = "outdated",
    system = "clasp",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
