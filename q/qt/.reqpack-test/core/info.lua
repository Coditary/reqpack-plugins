return {
  name = "qt info merges installed and remote metadata",
  fixtureRoot = "/tmp/opencode/qt-info-case",
  request = {
    action = "info",
    system = "qt",
    prompt = "qt.qt6.6111.addons.qtcharts",
    flags = { "data-root=/tmp/opencode/qt-info-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/qt-root",
  },
  fixtureFiles = {
    { path = ".reqpack-data/qt-root/MaintenanceTool", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-info-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-info-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-info-case/.reqpack-data/cache' 'list'", exitCode = 0, stdout = "Id: qt.qt6.6111.addons.qtcharts\n    Display name: Qt Charts\n    Version: 6.11.1-0-202601010101\n", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-info-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-info-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-info-case/.reqpack-data/cache' '--type' 'package' 'search' '^qt%.qt6%.6111%.addons%.qtcharts$'", exitCode = 0, stdout = "<availablepackages><package name=\"qt.qt6.6111.addons.qtcharts\" displayname=\"Qt Charts\" version=\"6.11.1-0-202601010101\"/></availablepackages>\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "qt.qt6.6111.addons.qtcharts",
    resultVersion = "6.11.1-0-202601010101",
  },
}
