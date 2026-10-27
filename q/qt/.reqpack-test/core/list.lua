return {
  name = "qt list installed packages",
  fixtureRoot = "/tmp/opencode/qt-list-case",
  request = {
    action = "list",
    system = "qt",
    flags = { "data-root=/tmp/opencode/qt-list-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/qt-root",
  },
  fixtureFiles = {
    { path = ".reqpack-data/qt-root/MaintenanceTool", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-list-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-list-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-list-case/.reqpack-data/cache' 'list'", exitCode = 0, stdout = "Id: qt.qt6.6111.linux_gcc_64\n    Display name: Desktop gcc 64-bit\n    Version: 6.11.1-0-202601010101\nId: qt.tools.qtcreator\n    Display name: Qt Creator\n    Version: 16.0.0-0-202601010102\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "qt.qt6.6111.linux_gcc_64",
  },
}
