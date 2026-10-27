return {
  name = "a2 update remote linux64",
  request = {
    action = "update",
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
      path = ".reqpack-data/installs/linux64/manifest.json",
      content = [[{"id":"linux64","source":"remote","revision":"oldrev1234567890","summary":"A2 Linux 64-bit profile","description":"Managed A2 Linux 64-bit distribution profile with Linux64 startup layout","homepage":"https://en.wikibooks.org/wiki/Oberon/A2","repository":"https://gitlab.inf.ethz.ch/felixf/oberon.git","entryPath":"Linux64","startScript":"Linux64/a2.sh","localPath":""}]],
    },
    {
      path = ".reqpack-data/cache/repository.json",
      content = [[{"revision":"newrev1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]],
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/cache/repository.json'", exitCode = 0, stdout = [[{"revision":"newrev1234567890abcdef1234567890abcdef12","repositoryUrl":"https://gitlab.inf.ethz.ch/felixf/oberon.git","cachedAt":"0"}]], stderr = "", success = true },
    { match = "git ls-remote 'https://gitlab.inf.ethz.ch/felixf/oberon.git' HEAD", exitCode = 0, stdout = "newrev1234567890abcdef1234567890abcdef12\tHEAD\n", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/.reqpack-data/installs/linux64/payload'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/installs/linux64/payload'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/installs/linux64'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
