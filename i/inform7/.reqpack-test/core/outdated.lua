return {
  name = "inform7 outdated empty by design",
  request = {
    action = "outdated",
    system = "inform7",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
