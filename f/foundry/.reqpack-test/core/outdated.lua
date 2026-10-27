return {
  name = "foundry outdated empty",
  request = {
    action = "outdated",
    system = "foundry",
  },
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  },
}
