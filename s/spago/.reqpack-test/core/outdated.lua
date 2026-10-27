return {
  name = "spago outdated empty",
  request = {
    action = "outdated",
    system = "spago",
  },
  fakeExec = {},
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
