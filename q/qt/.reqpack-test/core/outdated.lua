return {
  name = "qt outdated packages",
  fixtureRoot = "/tmp/opencode/qt-outdated-case",
  request = {
    action = "outdated",
    system = "qt",
    flags = { "data-root=/tmp/opencode/qt-outdated-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/qt-root",
  },
  fixtureFiles = {
    { path = ".reqpack-data/qt-root/MaintenanceTool", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-outdated-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-outdated-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-outdated-case/.reqpack-data/cache' 'check-updates'", exitCode = 0, stdout = "<?xml version=\"1.0\"?><updates><update name=\"qt.qt6.6111.linux_gcc_64\" version=\"6.11.2-0-202601020202\"/></updates>\n", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-outdated-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-outdated-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-outdated-case/.reqpack-data/cache' 'list'", exitCode = 0, stdout = "Id: qt.qt6.6111.linux_gcc_64\n    Display name: Desktop gcc 64-bit\n    Version: 6.11.1-0-202601010101\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "qt.qt6.6111.linux_gcc_64",
    resultVersion = "6.11.1-0-202601010101",
  },
}
