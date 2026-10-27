return {
  name = "red_cli outdated unsupported",
  request = {
    action = "outdated",
    system = "red_cli",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
