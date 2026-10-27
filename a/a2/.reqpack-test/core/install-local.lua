return {
  name = "a2 install local Linux64 directory",
  request = {
    action = "installLocal",
    system = "a2",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    localPath = "${fixtureRoot}/Linux64",
  },
  fixtureDirs = {
    "${fixtureRoot}/Linux64",
    ".reqpack-data/installs/linux64",
    ".reqpack-data/installs/linux64/payload",
  },
  fixtureFiles = {
    { path = "Linux64/a2.sh", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/installs/linux64/payload'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '${fixtureRoot}/Linux64/.' '${fixtureRoot}/.reqpack-data/installs/linux64/payload'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/installs/linux64'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
