return {
  name = "tads3 list managed installs",
  request = {
    action = "list",
    system = "tads3",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/state",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/state/installed.json",
      content = "[{\"archivePath\":\"${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip\",\"description\":\"Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3.\",\"fileName\":\"adv3Lite.zip\",\"homepage\":\"https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/\",\"installPath\":\"${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite\",\"installedAt\":\"2026-05-31T10:00:00Z\",\"mainLibraryFile\":\"adv3Lite.tl\",\"modifiedDate\":\"08-Dec-2025\",\"name\":\"adv3Lite\",\"origin\":\"remote\",\"packageId\":\"contributions/adv3lite\",\"packageType\":\"library\",\"repository\":\"ifarchive\",\"section\":\"contributions\",\"sourceUrl\":\"https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip\",\"summary\":\"Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3.\",\"version\":\"2.2.2\"}]",
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
      stdout = "[{\"archivePath\":\"${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip\",\"description\":\"Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3.\",\"fileName\":\"adv3Lite.zip\",\"homepage\":\"https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/\",\"installPath\":\"${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite\",\"installedAt\":\"2026-05-31T10:00:00Z\",\"mainLibraryFile\":\"adv3Lite.tl\",\"modifiedDate\":\"08-Dec-2025\",\"name\":\"adv3Lite\",\"origin\":\"remote\",\"packageId\":\"contributions/adv3lite\",\"packageType\":\"library\",\"repository\":\"ifarchive\",\"section\":\"contributions\",\"sourceUrl\":\"https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip\",\"summary\":\"Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3.\",\"version\":\"2.2.2\"}]",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 1,
      stdout = "",
      stderr = "",
      success = false,
    },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 1,
    resultName = "adv3Lite",
    resultVersion = "2.2.2",
  }
}
