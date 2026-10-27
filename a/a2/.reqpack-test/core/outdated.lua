return {
  name = "a2 outdated by cached revision",
  request = {
    action = "outdated",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data", "refresh" },
  },
  fixtureDirs = {
    ".reqpack-data/cache",
    ".reqpack-data/installs/linux64",
    ".reqpack-data/installs/linux64/payload",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/installs/linux64/manifest.json",
      content = [[{"id":"linux64","source":"remote","revision":"oldrev1234567890","summary":"A2 Linux 64-bit profile","description":"Managed A2 Linux 64-bit distribution profile with Linux64 startup layout","homepage":"https://en.wikibooks.org/wiki/Oberon/A2","repository":"https://gitlab.inf.ethz.ch/felixf/oberon.git","entryPath":"Linux64","startScript":"Linux64/a2.sh","localPath":""}]],
    },
  },
  fakeExec = {
    { match = "cat '.reqpack-data/cache/repository.json'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "git ls-remote 'https://gitlab.inf.ethz.ch/felixf/oberon.git' HEAD", exitCode = 0, stdout = "abcdef1234567890abcdef1234567890abcdef12\tHEAD\n", stderr = "", success = true },
    { match = "ls -1A '.reqpack-data/installs'", exitCode = 0, stdout = "linux64\n", stderr = "", success = true },
    { match = "mkdir -p '.reqpack-data/cache'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
    resultName = "",
    resultVersion = "",
  }
}
