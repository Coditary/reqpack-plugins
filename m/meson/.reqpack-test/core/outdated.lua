return {
  name = "meson outdated from wrap status",
  request = {
    action = "outdated",
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
      content = "libgee\tremote\t0.20.4\t1\t0.20.4\t1\t\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap\tlibgee\t\n",
    },
  },
  fakeExec = {
    { match = "cat '${fixtureRoot}/.reqpack-data/meson/state.tsv'", exitCode = 0, stdout = "libgee\tremote\t0.20.4\t1\t0.20.4\t1\t\t${fixtureRoot}/.reqpack-data/meson/workspace/subprojects/libgee.wrap\tlibgee\t\n", stderr = "", success = true },
    { match = "command -v 'meson' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v 'meson' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/meson/home' '${fixtureRoot}/.reqpack-data/meson/workspace' '${fixtureRoot}/.reqpack-data/meson/workspace/subprojects' '${fixtureRoot}/.reqpack-data/meson' '${fixtureRoot}/.reqpack-cache/meson/package-cache' '${fixtureRoot}/.reqpack-cache/meson/xdg-cache' '${fixtureRoot}/.reqpack-config/meson/xdg-config' '${fixtureRoot}/.reqpack-data/meson/xdg-data'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [=[test -f '${fixtureRoot}/.reqpack-data/meson/workspace/meson.build' || printf %s 'project('\''reqpack-meson-workspace'\'')
' > '${fixtureRoot}/.reqpack-data/meson/workspace/meson.build']=], exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [=[HOME='${fixtureRoot}/.reqpack-data/meson/home' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/meson/xdg-cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/meson/xdg-config' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/meson/xdg-data' MESON_PACKAGE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/meson/package-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' sh -lc 'cd "${fixtureRoot}/.reqpack-data/meson/workspace" && meson wrap status']=], exitCode = 0, stdout = "Subproject status\n libgee not up to date. Have 0.20.4 1, but 0.20.6 1 is available.\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "libgee",
    resultVersion = "0.20.4",
  },
}
