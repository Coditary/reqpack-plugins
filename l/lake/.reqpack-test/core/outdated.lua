return {
  name = "lake outdated empty when unsupported",
  request = {
    action = "outdated",
    system = "lake",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
