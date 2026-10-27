return {
  name = "docker outdated image",
  request = {
    action = "outdated",
    system = "docker",
  },
  fakeExec = {
    {
      match = "docker image ls --digests --no-trunc --format json",
      exitCode = 0,
      stdout = [=[{"Containers":"0","CreatedAt":"2026-05-30 12:00:00 +0000 UTC","CreatedSince":"1 hour ago","Digest":"sha256:old","ID":"sha256:def","Repository":"nginx","SharedSize":"N/A","Size":"187MB","Tag":"latest","UniqueSize":"N/A"}
]=],
      stderr = "",
      success = true,
    },
    {
      match = "docker image inspect 'nginx:latest'",
      exitCode = 0,
      stdout = [=[[{"Architecture":"amd64","Os":"linux","Id":"sha256:def","RepoTags":["nginx:latest"],"RepoDigests":["nginx@sha256:old"],"Size":191234567}]]=],
      stderr = "",
      success = true,
    },
    {
      match = "docker manifest inspect --verbose 'nginx:latest'",
      exitCode = 0,
      stdout = [=[[{"Ref":"docker.io/library/nginx:latest@sha256:new","Descriptor":{"digest":"sha256:new","platform":{"architecture":"amd64","os":"linux"}}}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "nginx:latest",
    resultVersion = "latest",
  }
}
