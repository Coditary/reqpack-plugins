return {
  name = "melpa install local package file",
  request = {
    action = "install",
    system = "melpa",
    localPath = "${fixtureRoot}/archive/example-pkg-1.0.0.tar",
  },
  fakeExec = {
    {
      match = "command -v 'emacs' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "REQPACK_MELPA_ACTION='install-local'",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, packageType=emacs-lisp, path=${fixtureRoot}/archive/example-pkg-1.0.0.tar}",
    },
  }
}
