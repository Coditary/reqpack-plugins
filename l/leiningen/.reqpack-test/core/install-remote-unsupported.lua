return {
  name = "leiningen install remote unsupported",
  request = {
    action = "install",
    system = "leiningen",
    packages = {
      { name = "cheshire", version = "5.12.0" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'lein' >/dev/null 2>&1",
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
      failed = "leiningen remote installs are not supported; use installLocal or project-specific dependency management",
      unavailable = "{reason=remote-install-unsupported}",
    },
  },
}
