return {
  name = "gleam install local unsupported",
  request = {
    action = "install",
    system = "gleam",
    localPath = "/tmp/demo-package",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "gleam installLocal is not supported; use path dependency in gleam.toml",
      unavailable = "{path=/tmp/demo-package, reason=local-install-unsupported}",
    },
  },
}
