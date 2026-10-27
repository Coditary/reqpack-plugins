return {
  name = "elpa install local tar file",
  request = {
    action = "install",
    system = "elpa",
    flags = { "data-root=${fixtureRoot}/.reqpack-data/elpa" },
    localPath = "/tmp/use-package.tar",
  },
  fakeExec = {
    {
      match = " install-local '${fixtureRoot}/.reqpack-data/elpa' '/tmp/use-package.tar'",
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
      installed = "{localTarget=true, packageType=emacs-lisp-package, path=/tmp/use-package.tar}",
    },
  }
}
