return {
  name = "a2 remove installed linux64",
  request = {
    action = "remove",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "linux64" },
    },
  },
  fakeExec = {
    { match = "cat '.reqpack-data/installs/linux64/manifest.json'", exitCode = 0, stdout = [[{"id":"linux64","source":"remote","revision":"abcdef1234567890","summary":"A2 Linux 64-bit profile","description":"Managed A2 Linux 64-bit distribution profile with Linux64 startup layout","homepage":"https://en.wikibooks.org/wiki/Oberon/A2","repository":"https://gitlab.inf.ethz.ch/felixf/oberon.git","entryPath":"Linux64","startScript":"Linux64/a2.sh","localPath":""}]], stderr = "", success = true },
    { match = "rm -rf '.reqpack-data/installs/linux64'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  fixtureDirs = {
    ".reqpack-data/installs/linux64/payload",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/installs/linux64/manifest.json",
      content = [[{"id":"linux64","source":"remote","revision":"abcdef1234567890","summary":"A2 Linux 64-bit profile","description":"Managed A2 Linux 64-bit distribution profile with Linux64 startup layout","homepage":"https://en.wikibooks.org/wiki/Oberon/A2","repository":"https://gitlab.inf.ethz.ch/felixf/oberon.git","entryPath":"Linux64","startScript":"Linux64/a2.sh","localPath":""}]],
    },
  },
  expect = {
    success = true,
    events = { "success" },
  }
}
