return {
  name = "podman outdated image",
  request = {
    action = "outdated",
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
      stdout = [=[[{"id":"img1","names":["docker.io/library/alpine:latest"],"digest":"sha256:old","created":"2026-05-30T12:00:00Z","size":12345}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "podman pull --quiet --policy newer 'docker.io/library/alpine:latest'",
      exitCode = 0,
      stdout = "sha256:new\n",
      stderr = "",
      success = true,
    },
    {
      match = "podman image inspect 'docker.io/library/alpine:latest'",
      exitCode = 0,
      stdout = [=[[{"Id":"img1","Digest":"sha256:new","RepoTags":["docker.io/library/alpine:latest"],"RepoDigests":["docker.io/library/alpine@sha256:new"],"Created":"2026-05-30T12:00:00Z","Architecture":"amd64","Os":"linux","ManifestType":"application/vnd.oci.image.manifest.v1+json","Size":12345,"Labels":{"org.opencontainers.image.description":"Alpine image"}}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "alpine",
    resultVersion = "latest",
  },
}
