return {
  name = "zig outdated empty",
  request = {
    action = "outdated",
    system = "zig",
  },
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  }
}
