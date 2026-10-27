return {
  name = "getit local install unsupported",
  request = {
    action = "install",
    system = "getit",
    localPath = "/tmp/package.json",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "GetIt local installs are not supported; use IDE Load Local Package flow",
      unavailable = "{path=/tmp/package.json, reason=local-install-unsupported}",
    },
  },
}
