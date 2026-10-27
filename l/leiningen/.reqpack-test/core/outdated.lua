return {
  name = "leiningen outdated empty",
  request = {
    action = "outdated",
    system = "leiningen",
  },
  fakeExec = {},
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  },
}
