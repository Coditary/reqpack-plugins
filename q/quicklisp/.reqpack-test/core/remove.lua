return {
  name = "quicklisp remove remote system",
  fixtureRoot = "/tmp/opencode/quicklisp-remove-case",
  request = {
    action = "remove",
    system = "quicklisp",
    flags = { "data-root=/tmp/opencode/quicklisp-remove-case/.reqpack-data" },
    packages = { { name = "alexandria" } },
  },
  fixtureDirs = {
    ".reqpack-data/quicklisp/home",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quicklisp/home/setup.lisp", content = ";; quicklisp setup\n" },
  },
  fakeExec = {
    { match = "command -v 'sbcl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/quicklisp-remove-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(let ((target \"alexandria\"))", exitCode = 0, stdout = "REQPACK\tITEM\talexandria\talexandria-20241012-git\talexandria-20241012-git\ttrue\tinstalled\tcommon-lisp-system\talexandria\t/tmp/opencode/quicklisp-remove-case/.reqpack-data/quicklisp/home/software/alexandria-20241012-git/\t\talexandria\tquicklisp\t2026-01-01\tfalse\n", stderr = "", success = true },
    { match = "(ql:uninstall name)", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "<lua-value>",
      success = "ok",
    },
  },
}
