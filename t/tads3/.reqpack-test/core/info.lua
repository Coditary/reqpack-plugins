return {
  name = "tads3 info exact remote library",
  request = {
    action = "info",
    system = "tads3",
    prompt = "contributions/adv3Lite",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
    },
  },
  fixtureDirs = {
    "${fixtureRoot}/.reqpack-data",
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
      match = "curl -fsSL 'https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/'",
      exitCode = 0,
      stdout = "<html><body></body></html>",
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://www.ifarchive.org/indexes/if-archive/programming/tads3/library/contributions/'",
      exitCode = 0,
      stdout = "<html><body><a href=\"/if-archive/programming/tads3/library/contributions/adv3Lite.zip\">adv3Lite.zip</a> [08-Dec-2025] Version 2.2.2 of adv3Lite, an alternative library for use with TADS 3, by Eric Eve. Freeware.</body></html>",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "adv3Lite",
    resultVersion = "2.2.2",
  }
}
