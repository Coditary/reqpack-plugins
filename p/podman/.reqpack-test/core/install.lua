return {
  name = "podman install image",
  request = {
    action = "install",
    system = "podman",
    packages = {
      { action = "install", name = "docker.io/library/alpine:3.20" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'podman' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "podman images --format json",
      exitCode = 0,
      stdout = "[]",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'podman' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "podman pull --quiet --policy missing 'docker.io/library/alpine:3.20'",
      exitCode = 0,
      stdout = "sha256:abc\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'podman' >/dev/null 2>&1",
      "podman pull --quiet --policy missing 'docker.io/library/alpine:3.20'",
    },
    events = { "installed", "success" },
  },
}
