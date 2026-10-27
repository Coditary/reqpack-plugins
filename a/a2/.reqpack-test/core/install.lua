return {
  name = "a2 install remote linux64",
  request = {
    action = "install",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "linux64" },
    },
  },
  fixtureDirs = {
    ".reqpack-data/cache",
    ".reqpack-data/installs/linux64",
    ".reqpack-data/installs/linux64/payload",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/cache/repository.json",
      content = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]],
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/cache/repository.json'", exitCode = 0, stdout = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]], stderr = "", success = true },
    { match = "git ls-remote 'https://gitlab.inf.ethz.ch/felixf/oberon.git' HEAD", exitCode = 0, stdout = "abcdef1234567890abcdef1234567890abcdef12\tHEAD\n", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/cache' '${fixtureRoot}/.reqpack-data/installs/linux64/payload'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/installs/linux64'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
