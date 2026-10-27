return {
  name = "podman remove image",
  request = {
    action = "remove",
    system = "podman",
    packages = {
      { action = "remove", name = "docker.io/library/alpine:latest" }
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
      stdout = [=[[{"id":"img1","names":["docker.io/library/alpine:latest"],"digest":"sha256:old","created":"2026-05-30T12:00:00Z","size":12345}]]=],
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
      match = "podman rmi --ignore 'docker.io/library/alpine:latest'",
      exitCode = 0,
      stdout = "Deleted: sha256:old\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'podman' >/dev/null 2>&1",
      "podman rmi --ignore 'docker.io/library/alpine:latest'",
    },
    events = { "deleted", "success" },
  },
}
