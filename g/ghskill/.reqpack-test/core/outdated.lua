return {
  name = "ghskill outdated empty",
  request = {
    action = "outdated",
    system = "ghskill",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
