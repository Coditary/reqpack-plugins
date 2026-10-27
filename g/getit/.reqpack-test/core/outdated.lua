return {
  name = "getit outdated unsupported",
  request = {
    action = "outdated",
    system = "getit",
  },
  expect = {
    success = true,
    resultCount = 0,
    events = { "outdated" },
  },
}
