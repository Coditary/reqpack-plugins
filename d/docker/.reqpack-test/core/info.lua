return {
  name = "docker info local image",
  request = {
    action = "info",
    system = "docker",
    prompt = "nginx:latest",
  },
  fakeExec = {
    {
      match = "docker image inspect 'nginx:latest'",
      exitCode = 0,
      stdout = [=[[{"Architecture":"amd64","Os":"linux","Id":"sha256:def","RepoTags":["nginx:latest"],"RepoDigests":["nginx@sha256:abc"],"Size":191234567}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "nginx:latest",
    resultVersion = "sha256:abc",
  }
}
