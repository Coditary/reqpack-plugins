return {
  name = "meson remove managed wrap",
  request = {
    action = "remove",
    system = "meson",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    packages = {
      { name = "libgee" },
    },
  },
  fixtureDirs = {
    ".reqpack-data/meson",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/meson/state.tsv",
      content = "libgee\tremote\t0.20.6\t1\t0.20.6\t1\t\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap\tlibgee\t\n",
    },
  },
  fakeExec = {
    { match = "rm -f '${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "rm -rf '${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/meson' && printf %s '' > '${fixtureRoot}/.reqpack-data/meson/state.tsv'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    result = true,
  },
}
