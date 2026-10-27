return {
  name = "podman search images",
  request = {
    action = "search",
    system = "podman",
    prompt = "alpine",
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
      match = "podman search --limit 25 --format '{{.Index}}\t{{.Name}}\t{{.Description}}\t{{.Stars}}\t{{.Official}}\t{{.Automated}}' 'alpine'",
      exitCode = 0,
      stdout = "docker.io\tlibrary/alpine\tA minimal Docker image\t12345\t[OK]\t\nquay.io\tpodman/stable\tStable Podman image\t99\t\t[OK]\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v 'podman' >/dev/null 2>&1",
      "podman search --limit 25 --format '{{.Index}}\t{{.Name}}\t{{.Description}}\t{{.Stars}}\t{{.Official}}\t{{.Automated}}' 'alpine'",
    },
    resultCount = 2,
    resultName = "alpine",
    resultVersion = "latest",
    events = { "searched" },
  },
}
