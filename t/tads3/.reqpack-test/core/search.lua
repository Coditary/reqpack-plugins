return {
  name = "tads3 search remote libraries",
  request = {
    action = "search",
    system = "tads3",
    prompt = "adv3",
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
      stdout = "<html><body><a href=\"/if-archive/programming/tads3/library/tads_lib_313.zip\">tads_lib_313.zip</a> [11-Jan-2024] Standard TADS 3 library.</body></html>",
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
    events = { "searched" },
    resultCount = 1,
    resultName = "adv3Lite",
    resultVersion = "2.2.2",
  }
}
