return {
  name = "dub search packages",
  fixtureRoot = "../fixtures-search",
  request = {
    action = "search",
    system = "dub",
    prompt = "vibe",
    flags = { "cache-root=${fixtureRoot}/.reqpack-data" },
  },
  fakeExec = {
    {
      match = "command -v dub >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub search vibe",
      exitCode = 0,
      stdout = "vibe-d 0.9.6 - Async web framework\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "vibe-d",
    events = { "searched" },
  }
}
