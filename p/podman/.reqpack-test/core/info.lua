return {
  name = "podman info installed image",
  request = {
    action = "info",
    system = "podman",
    prompt = "docker.io/library/alpine:latest",
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
      match = "podman image inspect 'docker.io/library/alpine:latest'",
      exitCode = 0,
      stdout = [=[[{"Id":"img1","Digest":"sha256:old","RepoTags":["docker.io/library/alpine:latest"],"RepoDigests":["docker.io/library/alpine@sha256:old"],"Created":"2026-05-30T12:00:00Z","Architecture":"amd64","Os":"linux","ManifestType":"application/vnd.oci.image.manifest.v1+json","Size":12345,"Labels":{"org.opencontainers.image.description":"A minimal Docker image","org.opencontainers.image.url":"https://hub.docker.com/_/alpine"}}]]=],
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
