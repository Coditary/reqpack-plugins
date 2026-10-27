return {
  name = "elm-package install local unsupported",
  request = {
    action = "install",
    system = "elm-package",
    localPath = "/tmp/pkg.tar.gz",
    packages = {
      { name = "elm-lang/core", path = "/tmp/pkg.tar.gz" }
    },
  },
  fakeExec = {
    {
      match = "command -v elm-package >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "installLocal is not supported for elm-package; use published registry packages",
      unavailable = "{path=/tmp/pkg.tar.gz, reason=local-install-unsupported}",
    },
  },
}
