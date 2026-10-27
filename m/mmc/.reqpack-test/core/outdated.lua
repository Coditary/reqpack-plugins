return {
  name = "mmc outdated unsupported",
  request = {
    action = "outdated",
    system = "mmc",
    flags = {
      "cache-root=${fixtureRoot}/cache"
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  },
}
