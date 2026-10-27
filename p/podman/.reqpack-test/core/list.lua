return {
  name = "podman list images",
  request = {
    action = "list",
    system = "podman",
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
      stdout = [=[[
  {"id":"img1","names":["docker.io/library/alpine:latest"],"digest":"sha256:old","created":"2026-05-30T12:00:00Z","size":12345},
  {"id":"img2","names":["quay.io/podman/stable:latest"],"digest":"sha256:stable","created":"2026-05-30T10:00:00Z","size":67890}
]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "alpine",
    resultVersion = "latest",
  },
}
