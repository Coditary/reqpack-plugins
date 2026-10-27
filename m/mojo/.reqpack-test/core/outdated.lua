return {
  name = "mojo outdated returns empty",
  request = {
    action = "outdated",
    system = "mojo",
  },
  fakeExec = {},
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  },
}
