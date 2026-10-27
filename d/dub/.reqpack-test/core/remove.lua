return {
  name = "dub remove shared package",
  fixtureRoot = "../fixtures-remove",
  request = {
    action = "remove",
    system = "dub",
    flags = { "cache-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "vibe-d", packageType = "package" }
    },
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub remove vibe-d '--version=*' -n",
      exitCode = 0,
      stdout = "Removed vibe-d\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
  }
}
