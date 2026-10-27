return {
  name = "a2 list manifests",
  request = {
    action = "list",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
  },
  fakeExec = {
    { match = "ls -1A '.reqpack-data/installs'", exitCode = 0, stdout = "linux64\ndocumentation\n", stderr = "", success = true },
    { match = "cat '.reqpack-data/cache/repository.json'", exitCode = 0, stdout = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]], stderr = "", success = true },
  },
  fixtureDirs = {
    ".reqpack-data/installs/linux64/payload",
    ".reqpack-data/installs/documentation/payload",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/cache/repository.json",
      content = [[{"revision":"abcdef1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]],
    },
    {
      path = ".reqpack-data/installs/linux64/manifest.json",
      content = [[{"id":"linux64","source":"remote","revision":"abcdef1234567890abcdef1234567890abcdef12","summary":"A2 Linux 64-bit profile","description":"Managed A2 Linux 64-bit distribution profile with Linux64 startup layout","homepage":"https://en.wikibooks.org/wiki/Oberon/A2","repository":"https://gitlab.inf.ethz.ch/felixf/oberon.git","entryPath":"Linux64","startScript":"Linux64/a2.sh","localPath":""}]],
    },
    {
      path = ".reqpack-data/installs/documentation/manifest.json",
      content = [[{"id":"documentation","source":"remote","revision":"abcdef1234567890abcdef1234567890abcdef12","summary":"A2 documentation profile","description":"Managed A2 documentation profile for bundled manuals and docs","homepage":"https://gitlab.inf.ethz.ch/felixf/oberon/-/blob/main/ocp/Documentation/A2Documentation.pdf?ref_type=heads","repository":"https://gitlab.inf.ethz.ch/felixf/oberon.git","entryPath":"ocp/Documentation","startScript":"","localPath":""}]],
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 0,
    resultName = "",
    resultVersion = "",
  }
}
