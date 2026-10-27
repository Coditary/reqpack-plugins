return {
  name = "a2 info linux64",
  request = {
    action = "info",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "linux-64",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/cache/repository.json",
      content = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]],
    },
  },
  fakeExec = {
    { match = "cat '.reqpack-data/cache/repository.json'", exitCode = 0, stdout = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]], stderr = "", success = true },
    { match = "cat '.reqpack-data/installs/linux64/manifest.json'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "linux64",
    resultVersion = "",
  }
}
