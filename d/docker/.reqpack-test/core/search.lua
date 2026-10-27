return {
  name = "docker search remote images",
  request = {
    action = "search",
    system = "docker",
    prompt = "nginx",
  },
  fakeExec = {
    {
      match = "docker search --limit 25 --no-trunc --format '{{json .}}' 'nginx'",
      exitCode = 0,
      stdout = [=[{"Description":"Official build of Nginx.","IsOfficial":"true","Name":"nginx","StarCount":"21282"}
]=],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "nginx:latest",
    resultVersion = "latest",
  }
}
