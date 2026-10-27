return {
  name = "podman info remote fallback",
  request = {
    action = "info",
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
      match = "podman image inspect 'alpine'",
      exitCode = 125,
      stdout = "",
      stderr = "Error: alpine: image not known\n",
      success = false,
    },
    {
      match = "podman image inspect 'docker.io/library/alpine:latest'",
      exitCode = 125,
      stdout = "",
      stderr = "Error: docker.io/library/alpine:latest: image not known\n",
      success = false,
    },
    {
      match = "podman search --limit 25 --format '{{.Index}}\t{{.Name}}\t{{.Description}}\t{{.Stars}}\t{{.Official}}\t{{.Automated}}' 'docker.io/library/alpine'",
      exitCode = 0,
      stdout = "docker.io\tlibrary/alpine\tA minimal Docker image\t12345\t[OK]\t\n",
      stderr = "",
      success = true,
    },
    {
      match = "podman search --list-tags --limit 25 --format '{{.Name}}\t{{.Tag}}' 'docker.io/library/alpine'",
      exitCode = 0,
      stdout = "docker.io/library/alpine\tlatest\ndocker.io/library/alpine\t3.20\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "alpine",
    resultVersion = "latest",
  },
}
