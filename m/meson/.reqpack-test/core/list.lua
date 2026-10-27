return {
  name = "meson list managed wraps",
  request = {
    action = "list",
    system = "meson",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
  },
  fixtureDirs = {
    ".reqpack-data/meson",
  },
  fixtureFiles = {
    {
      path = ".reqpack-data/meson/state.tsv",
      content = "glib\tlocal\t2.80.0\t\t2.80.0\t\t${fixtureRoot}/downloads/glib.wrap\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/glib.wrap\tglib-2.80.0\tglib-2.0,gobject-2.0\nlibgee\tremote\t0.20.6\t1\t0.20.6\t1\t\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap\tlibgee\t\n",
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/meson/state.tsv'", exitCode = 0, stdout = "glib\tlocal\t2.80.0\t\t2.80.0\t\t${fixtureRoot}/downloads/glib.wrap\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/glib.wrap\tglib-2.80.0\tglib-2.0,gobject-2.0\nlibgee\tremote\t0.20.6\t1\t0.20.6\t1\t\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap\tlibgee\t\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "glib",
    resultVersion = "2.80.0",
  },
}
