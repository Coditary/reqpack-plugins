return {
  name = "odpkg install local unsupported",
  fixtureRoot = "/tmp/opencode/odpkg-install-local",
  request = {
    action = "install",
    system = "odpkg",
    localPath = "/tmp/opencode/odpkg-install-local/local/pkg",
  },
  environment = {
    REQPACK_TEST_FIXTURE_ROOT = "/tmp/opencode/odpkg-install-local",
  },
  expect = {
    success = false,
    events = { "failed" },
    eventPayloads = {
      failed = "odpkg installLocal is not supported",
    },
  },
}
