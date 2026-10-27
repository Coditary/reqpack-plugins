return {
  name = "cpanm outdated empty by design",
  request = {
    action = "outdated",
    system = "cpanm",
  },
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  }
}
