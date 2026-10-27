return {
  name = "a2 search aliases and summaries",
  request = {
    action = "search",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "docs",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/cache/repository.json",
      content = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]],
    },
  },
  fakeExec = {
    { match = "cat '.reqpack-data/cache/repository.json'", exitCode = 0, stdout = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]], stderr = "", success = true },
    { match = "ls -1A '.reqpack-data/installs'", exitCode = 1, stdout = "", stderr = "", success = false },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "documentation",
    resultVersion = "",
  }
}
