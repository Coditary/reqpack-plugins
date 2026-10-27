return {
  name = "dub install shared package",
  fixtureRoot = "../fixtures-install",
  request = {
    action = "install",
    system = "dub",
    flags = { "cache-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "vibe-d", version = "0.9.5", packageType = "package" }
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
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub fetch vibe-d --version=0.9.5",
      exitCode = 0,
      stdout = "Fetched vibe-d 0.9.5\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "command -v dub >/dev/null 2>&1",
      "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C DUB_HOME=${fixtureRoot}/.reqpack-data/dub-home dub fetch vibe-d --version=0.9.5"
    },
    events = { "installed", "success" },
  }
}
