return {
  name = "tads3 list outdated libraries",
  request = {
    action = "outdated",
    system = "tads3",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data/state",
    "${fixtureRoot}/.reqpack-data",
  },
  fixtureFiles = {
    {
      path = "${fixtureRoot}/.reqpack-data/state/installed.json",
      content = "[{\"archivePath\":\"${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip\",\"description\":\"Version 2.2.1 of adv3Lite.\",\"fileName\":\"adv3Lite.zip\",\"homepage\":\"https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/\",\"installPath\":\"${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite\",\"installedAt\":\"2026-05-31T10:00:00Z\",\"mainLibraryFile\":\"adv3Lite.tl\",\"modifiedDate\":\"01-Dec-2025\",\"name\":\"adv3Lite\",\"origin\":\"remote\",\"packageId\":\"contributions/adv3lite\",\"packageType\":\"library\",\"repository\":\"ifarchive\",\"section\":\"contributions\",\"sourceUrl\":\"https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip\",\"summary\":\"Version 2.2.1 of adv3Lite.\",\"version\":\"2.2.1\"}]",
    },
  },
  fakeExec = {
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
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
      stdout = "[{\"archivePath\":\"${fixtureRoot}/.reqpack-data/archives/contributions/adv3Lite.zip\",\"description\":\"Version 2.2.1 of adv3Lite.\",\"fileName\":\"adv3Lite.zip\",\"homepage\":\"https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/\",\"installPath\":\"${fixtureRoot}/.reqpack-data/packages/contributions/adv3lite\",\"installedAt\":\"2026-05-31T10:00:00Z\",\"mainLibraryFile\":\"adv3Lite.tl\",\"modifiedDate\":\"01-Dec-2025\",\"name\":\"adv3Lite\",\"origin\":\"remote\",\"packageId\":\"contributions/adv3lite\",\"packageType\":\"library\",\"repository\":\"ifarchive\",\"section\":\"contributions\",\"sourceUrl\":\"https://www.ifarchive.org/if-archive/programming/tads3/library/contributions/adv3Lite.zip\",\"summary\":\"Version 2.2.1 of adv3Lite.\",\"version\":\"2.2.1\"}]",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/'",
      exitCode = 0,
      stdout = "<html><body></body></html>",
      stderr = "",
      success = true,
    },
    {
      match = "command -v 'curl' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/'",
      exitCode = 0,
      stdout = "<html><body><a href=\"/if-archive/programming/tads3/library/contributions/adv3Lite.zip\">adv3Lite.zip</a> [08-Dec-2025] Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3, by Eric Eve.</body></html>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "adv3Lite",
    resultVersion = "2.2.1",
  }
}
