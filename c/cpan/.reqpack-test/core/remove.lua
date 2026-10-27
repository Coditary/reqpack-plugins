return {
  name = "cpan remove unsupported",
  request = {
    action = "remove",
    system = "cpan",
    packages = {
      { name = "Try::Tiny" }
    },
  },
  expect = {
    success = false,
    events = { "unavailable", "failed" },
    eventPayloads = {
      failed = "cpan remove is unsupported",
      unavailable = "{name=Try::Tiny, reason=remove-unsupported}",
    },
  }
}
