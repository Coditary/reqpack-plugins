return {
  name = "qt update selected package",
  fixtureRoot = "/tmp/opencode/qt-update-case",
  request = {
    action = "update",
    system = "qt",
    flags = { "data-root=/tmp/opencode/qt-update-case/.reqpack-data" },
    packages = {
      { name = "qt.qt6.6111.linux_gcc_64" },
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
    { match = "test -x '/tmp/opencode/qt-update-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-update-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-update-case/.reqpack-data/cache' '--accept-licenses' '--accept-obligations' '--default-answer' '--confirm-command' 'update' 'qt.qt6.6111.linux_gcc_64'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  },
}
