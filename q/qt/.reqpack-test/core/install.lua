return {
  name = "qt install bootstraps online installer",
  fixtureRoot = "/tmp/opencode/qt-install-case",
  request = {
    action = "install",
    system = "qt",
    flags = { "data-root=/tmp/opencode/qt-install-case/.reqpack-data" },
    packages = {
      { name = "qt.qt6.6111.linux_gcc_64" },
    },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-install-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -x '/tmp/opencode/qt-install-case/.reqpack-data/qt-root/MaintenanceTool.run'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -x '/tmp/opencode/qt-install-case/.reqpack-data/qt-root/maintenancetool'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -x '/tmp/opencode/qt-install-case/.reqpack-data/qt-root/bin/MaintenanceTool'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "command -v 'MaintenanceTool' >/dev/null 2>&1", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "command -v 'maintenancetool' >/dev/null 2>&1", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "test -x '/tmp/opencode/qt-install-case/.reqpack-data/downloads/qt-online-installer-linux-x64-online.run'", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "mkdir -p '/tmp/opencode/qt-install-case/.reqpack-data/downloads' && curl -fL --output '/tmp/opencode/qt-install-case/.reqpack-data/downloads/qt-online-installer-linux-x64-online.run' 'https://download.qt.io/official_releases/online_installers/qt-online-installer-linux-x64-online.run' && chmod +x '/tmp/opencode/qt-install-case/.reqpack-data/downloads/qt-online-installer-linux-x64-online.run'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-install-case/.reqpack-data/downloads/qt-online-installer-linux-x64-online.run' '--cache-path' '/tmp/opencode/qt-install-case/.reqpack-data/cache' '--accept-licenses' '--accept-obligations' '--default-answer' '--confirm-command' '--root' '/tmp/opencode/qt-install-case/.reqpack-data/qt-root' 'install' 'qt.qt6.6111.linux_gcc_64'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  },
}
