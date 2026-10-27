return {
  name = "opa outdated empty",
  request = {
    action = "outdated",
    system = "opa",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
