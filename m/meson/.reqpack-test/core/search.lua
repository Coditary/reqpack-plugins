return {
  name = "meson search parses dependency redirect",
  request = {
    action = "search",
    system = "meson",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "cache-root=${fixtureRoot}/.reqpack-cache",
      "config-root=${fixtureRoot}/.reqpack-config",
    },
    prompt = "gee",
  },
  fakeExec = {
    { match = "command -v 'meson' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '${fixtureRoot}/.reqpack-data/meson/home' '${fixtureRoot}/.reqpack-data/meson/workspace' '${fixtureRoot}/.reqpack-data/meson/workspace/subprojects' '${fixtureRoot}/.reqpack-data/meson' '${fixtureRoot}/.reqpack-cache/meson/package-cache' '${fixtureRoot}/.reqpack-cache/meson/xdg-cache' '${fixtureRoot}/.reqpack-config/meson/xdg-config' '${fixtureRoot}/.reqpack-data/meson/xdg-data'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [=[test -f '${fixtureRoot}/.reqpack-data/meson/workspace/meson.build' || printf %s 'project('\''reqpack-meson-workspace'\'')
' > '${fixtureRoot}/.reqpack-data/meson/workspace/meson.build']=], exitCode = 0, stdout = "", stderr = "", success = true },
    { match = [=[HOME='${fixtureRoot}/.reqpack-data/meson/home' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-cache/meson/xdg-cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-config/meson/xdg-config' XDG_DATA_HOME='${fixtureRoot}/.reqpack-data/meson/xdg-data' MESON_PACKAGE_CACHE_DIR='${fixtureRoot}/.reqpack-cache/meson/package-cache' NO_COLOR='1' LC_ALL='C' LANG='C' LANGUAGE='C' sh -lc 'cd "${fixtureRoot}/.reqpack-data/meson/workspace" && meson wrap search '\''gee'\''']=], exitCode = 0, stdout = "libgee\nDependency gee-0.8 found in wrap libgee\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "libgee",
  },
}
