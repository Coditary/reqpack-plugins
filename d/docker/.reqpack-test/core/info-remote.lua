return {
  name = "docker info remote fallback",
  request = {
    action = "info",
    system = "docker",
    prompt = "hello-world",
  },
  fakeExec = {
    {
      match = "docker image inspect 'hello-world:latest'",
      exitCode = 1,
      stdout = "[]",
      stderr = "Error response from daemon: No such image: hello-world:latest",
      success = false,
    },
    {
      match = "docker manifest inspect --verbose 'hello-world:latest'",
      exitCode = 0,
      stdout = [=[[{"Ref":"docker.io/library/hello-world:latest@sha256:new","Descriptor":{"digest":"sha256:new","platform":{"architecture":"amd64","os":"linux"}},"OCIManifest":{"annotations":{"org.opencontainers.image.url":"https://hub.docker.com/_/hello-world"}}}]]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "hello-world:latest",
    resultVersion = "latest",
  }
}
