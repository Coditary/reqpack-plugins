return {
  name = "podman install local archive",
  request = {
    action = "install",
    system = "podman",
    localPath = "/tmp/alpine.tar",
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
      match = "podman load --quiet --input '/tmp/alpine.tar'",
      exitCode = 0,
      stdout = "Loaded image: docker.io/library/alpine:latest\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'podman' >/dev/null 2>&1",
      "podman load --quiet --input '/tmp/alpine.tar'",
    },
    events = { "installed", "success" },
  },
}
