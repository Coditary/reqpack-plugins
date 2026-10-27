return {
  name = "docker list local images",
  request = {
    action = "list",
    system = "docker",
  },
  fakeExec = {
    {
      match = "docker image ls --digests --no-trunc --format json",
      exitCode = 0,
      stdout = [=[{"Containers":"0","CreatedAt":"2026-05-30 12:00:00 +0000 UTC","CreatedSince":"1 hour ago","Digest":"sha256:abc","ID":"sha256:def","Repository":"nginx","SharedSize":"N/A","Size":"187MB","Tag":"latest","UniqueSize":"N/A"}
]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "nginx:latest",
    resultVersion = "latest",
  }
}
