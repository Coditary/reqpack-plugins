return {
  name = "tads3 install local library file",
  request = {
    action = "installLocal",
    system = "tads3",
    localPath = "${fixtureRoot}/local/scenes.t",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data",
    "${fixtureRoot}/.reqpack-data/cache",
    "${fixtureRoot}/.reqpack-data/archives",
    "${fixtureRoot}/.reqpack-data/archives/local",
    "${fixtureRoot}/.reqpack-data/packages",
    "${fixtureRoot}/.reqpack-data/packages/local",
    "${fixtureRoot}/.reqpack-data/state",
    "${fixtureRoot}/local",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/local/scenes.t",
      content = "versionInfo: object;\n",
    },
  },
  fakeExec = {
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/cache' '${fixtureRoot}/.reqpack-data/archives' '${fixtureRoot}/.reqpack-data/packages' '${fixtureRoot}/.reqpack-data/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/.reqpack-data/state/installed.json'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -d '${fixtureRoot}/local/scenes.t'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -f '${fixtureRoot}/local/scenes.t'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/packages/local'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/archives/local'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/.reqpack-data/packages/local/scenes' && mkdir -p '${fixtureRoot}/.reqpack-data/archives/local' '${fixtureRoot}/.reqpack-data/packages/local/scenes' && cp '${fixtureRoot}/local/scenes.t' '${fixtureRoot}/.reqpack-data/archives/local/scenes.t' && cp '${fixtureRoot}/local/scenes.t' '${fixtureRoot}/.reqpack-data/packages/local/scenes/scenes.t'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/state' && printf '%s' '[{\"archivePath\"", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
