return {
  name = "inform7 update noop success",
  request = {
    action = "update",
    system = "inform7",
    flags = {
      "data-root=${fixtureRoot}/cache"
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  },
}
