return {
  name = "tads3 install remote zip library",
  request = {
    action = "install",
    system = "tads3",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
    packages = {
      { name = "adv3Lite" },
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data",
    "${fixtureRoot}/.reqpack-data/cache",
    "${fixtureRoot}/.reqpack-data/archives",
    "${fixtureRoot}/.reqpack-data/archives/contributions",
    "${fixtureRoot}/.reqpack-data/packages",
    "${fixtureRoot}/.reqpack-data/packages/contributions",
    "${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite",
    "${fixtureRoot}/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite/adv3Lite.tl",
      content = "name: adv3Lite\n",
    },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/cache' '${fixtureRoot}/.reqpack-data/archives' '${fixtureRoot}/.reqpack-data/packages' '${fixtureRoot}/.reqpack-data/state'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '${fixtureRoot}/.reqpack-data/state/installed.json'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "curl -fsSL 'https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/'", exitCode = 0, stdout = "<html><body></body></html>", stderr = "", success = true },
    { match = "curl -fsSL 'https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/'", exitCode = 0, stdout = "<html><body><a href=\"/if-archive/programming/tads3/library/contributions/adv3Lite.zip\">adv3Lite.zip</a> [08-Dec-2025] Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3, by Eric Eve.</body></html>", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/archives/contributions'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/packages/contributions'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "curl -fsSL 'https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip'", exitCode = 0, stdout = "PK\\003\\004", stderr = "", success = true },
    { match = "command -v 'unzip' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite' && mkdir -p '${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite' && unzip -oq '${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip' -d '${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "find '${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite' -type f", exitCode = 0, stdout = "${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite/adv3Lite.tl\n", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/state' && printf '%s' '[{\"archivePath\"", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
