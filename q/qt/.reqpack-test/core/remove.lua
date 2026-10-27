return {
  name = "qt remove installed package",
  fixtureRoot = "/tmp/opencode/qt-remove-case",
  request = {
    action = "remove",
    system = "qt",
    flags = { "data-root=/tmp/opencode/qt-remove-case/.reqpack-data" },
    packages = {
      { name = "qt.qt6.6111.addons.qtcharts" },
    },
  },
  fixtureDirs = {
    ".reqpack-data/qt-root",
  },
  fixtureFiles = {
    { path = ".reqpack-data/qt-root/MaintenanceTool", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-remove-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-remove-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-remove-case/.reqpack-data/cache' '--accept-licenses' '--accept-obligations' '--default-answer' '--confirm-command' 'remove' 'qt.qt6.6111.addons.qtcharts'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  },
}
