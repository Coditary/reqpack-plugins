return {
  name = "carbon outdated empty",
  request = {
    action = "outdated",
    system = "carbon",
  },
  fakeExec = {},
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  }
}
