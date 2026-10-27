return {
  name = "elpa install local el file",
  request = {
    action = "install",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    localPath = "/tmp/use-package.el",
  },
  fakeExec = {
    {
      match = " install-local '${fixtureRoot}/.reqpack-data/elpa' '/tmp/use-package.el'",
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
      installed = "{localTarget=true, packageType=emacs-lisp-package, path=/tmp/use-package.el}",
    },
  }
}
