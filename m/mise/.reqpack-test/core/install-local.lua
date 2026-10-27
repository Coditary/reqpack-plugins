return {
  name = "mise local install unsupported",
  request = {
    action = "install",
    system = "mise",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    localPath = "/tmp/mise.toml",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "mise local installs are not supported",
      unavailable = "{path=/tmp/mise.toml, reason=local-install-unsupported}",
    },
  }
}
