return {
  name = "qt search remote packages",
  fixtureRoot = "/tmp/opencode/qt-search-case",
  request = {
    action = "search",
    system = "qt",
    prompt = "charts",
    flags = { "data-root=/tmp/opencode/qt-search-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/qt-root",
  },
  fixtureFiles = {
    { path = ".reqpack-data/qt-root/MaintenanceTool", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-search-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-search-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-search-case/.reqpack-data/cache' '--type' 'package' 'search' 'charts'", exitCode = 0, stdout = "<availablepackages><package name=\"qt.qt6.6111.addons.qtcharts\" displayname=\"Qt Charts\" version=\"6.11.1-0-202601010101\"/></availablepackages>\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "qt.qt6.6111.addons.qtcharts",
    resultVersion = "6.11.1-0-202601010101",
  },
}
