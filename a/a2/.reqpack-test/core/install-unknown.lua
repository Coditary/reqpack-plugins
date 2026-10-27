return {
  name = "a2 install unknown profile fails",
  request = {
    action = "install",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "unknown-profile" },
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/cache/repository.json'", exitCode = 0, stdout = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]], stderr = "", success = true },
    { match = "git ls-remote 'https://gitlab.inf.ethz.ch/felixf/oberon.git' HEAD", exitCode = 0, stdout = "abcdef1234567890abcdef1234567890abcdef12\tHEAD\n", stderr = "", success = true },
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/cache/repository.json",
      content = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]],
    },
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
  }
}
