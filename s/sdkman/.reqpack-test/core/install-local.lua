return {
  name = "sdkman install local unsupported",
  request = {
    action = "install",
    system = "sdkman",
    localPath = "/tmp/groovy-local",
  },
  fakeExec = {
    {
      match = "test -f \"$HOME/.sdkman/bin/sdkman-init.sh\"",
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
      failed = "sdkman installLocal is not supported; use install with candidate name and version",
      unavailable = "{path=/tmp/groovy-local, reason=local-install-unsupported}",
    },
  }
}
