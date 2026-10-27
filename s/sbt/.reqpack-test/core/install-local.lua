return {
  name = "sbt local install unsupported",
  fixtureRoot = "/tmp/opencode/sbt-install-local-case",
  request = {
    action = "install",
    system = "sbt",
    localPath = "/tmp/example.jar",
  },
  fakeExec = {},
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "sbt local installs are not supported",
      unavailable = "{path=/tmp/example.jar, reason=local-install-unsupported}",
    },
  }
}
