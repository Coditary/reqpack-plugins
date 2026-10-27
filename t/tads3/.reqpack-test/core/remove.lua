return {
  name = "tads3 remove managed library",
  request = {
    action = "remove",
    system = "tads3",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
    packages = {
      { name = "contributions/adv3lite" },
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/state/installed.json",
      content = "[{\"archivePath\":\"${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip\",\"description\":\"Version 2.2.2 of adv3Lite.\",\"fileName\":\"adv3Lite.zip\",\"homepage\":\"https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/\",\"installPath\":\"${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite\",\"installedAt\":\"2026-05-31T10:00:00Z\",\"mainLibraryFile\":\"adv3Lite.tl\",\"modifiedDate\":\"08-Dec-2025\",\"name\":\"adv3Lite\",\"origin\":\"remote\",\"packageId\":\"contributions/adv3lite\",\"packageType\":\"library\",\"repository\":\"ifarchive\",\"section\":\"contributions\",\"sourceUrl\":\"https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip\",\"summary\":\"Version 2.2.2 of adv3Lite.\",\"version\":\"2.2.2\"}]",
    },
  },
  fakeExec = {
    {
      match = "test -f '${fixtureRoot}/.reqpack-data/state/installed.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "cat '${fixtureRoot}/.reqpack-data/state/installed.json'",
      exitCode = 0,
      stdout = "[{\"archivePath\":\"${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip\",\"description\":\"Version 2.2.2 of adv3Lite.\",\"fileName\":\"adv3Lite.zip\",\"homepage\":\"https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/\",\"installPath\":\"${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite\",\"installedAt\":\"2026-05-31T10:00:00Z\",\"mainLibraryFile\":\"adv3Lite.tl\",\"modifiedDate\":\"08-Dec-2025\",\"name\":\"adv3Lite\",\"origin\":\"remote\",\"packageId\":\"contributions/adv3lite\",\"packageType\":\"library\",\"repository\":\"ifarchive\",\"section\":\"contributions\",\"sourceUrl\":\"https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip\",\"summary\":\"Version 2.2.2 of adv3Lite.\",\"version\":\"2.2.2\"}]",
      stderr = "",
      success = true,
    },
    {
      match = "rm -rf '${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "mkdir -p '${fixtureRoot}/.reqpack-data/state' && printf '%s' '[]' > '${fixtureRoot}/.reqpack-data/state/installed.json'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
