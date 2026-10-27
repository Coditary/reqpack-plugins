return {
  name = "qt install local qbsp repository",
  fixtureRoot = "/tmp/opencode/qt-install-local-case",
  request = {
    action = "install",
    system = "qt",
    flags = { "data-root=/tmp/opencode/qt-install-local-case/.reqpack-data" },
    localPath = "/tmp/opencode/qt-install-local-case/board.qbsp",
  },
  fixtureDirs = {
    ".reqpack-data/qt-root",
  },
  fixtureFiles = {
    { path = ".reqpack-data/qt-root/MaintenanceTool", content = "#!/bin/sh\n" },
  },
  fakeExec = {
    { match = "command -v 'curl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -x '/tmp/opencode/qt-install-local-case/.reqpack-data/qt-root/MaintenanceTool'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "LC_ALL='C' LANG='C' LANGUAGE='C' NO_COLOR='1' '/tmp/opencode/qt-install-local-case/.reqpack-data/qt-root/MaintenanceTool' '--cache-path' '/tmp/opencode/qt-install-local-case/.reqpack-data/cache' '--accept-licenses' '--accept-obligations' '--default-answer' '--confirm-command' '--install-compressed-repository' '/tmp/opencode/qt-install-local-case/board.qbsp'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/opencode/qt-install-local-case/board.qbsp}",
      success = "ok",
    },
  },
}
