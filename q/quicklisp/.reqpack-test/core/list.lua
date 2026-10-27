return {
  name = "quicklisp list installed and local systems",
  fixtureRoot = "/tmp/opencode/quicklisp-list-case",
  request = {
    action = "list",
    system = "quicklisp",
    flags = { "data-root=/tmp/opencode/quicklisp-list-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quicklisp/home",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quicklisp/home/setup.lisp", content = ";; quicklisp setup\n" },
  },
  fakeExec = {
    { match = "command -v 'sbcl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/quicklisp-list-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(ql:list-local-systems)", exitCode = 0, stdout = "REQPACK\tITEM\texample-local\tlocal\tlocal\ttrue\tinstalled\tcommon-lisp-system\tlocal project\t/tmp/opencode/quicklisp-list-case/.reqpack-data/quicklisp/home/local-projects/example-local/\t\t\tlocal\t\ttrue\nREQPACK\tITEM\talexandria\talexandria-20241012-git\talexandria-20241012-git\ttrue\tinstalled\tcommon-lisp-system\talexandria\t/tmp/opencode/quicklisp-list-case/.reqpack-data/quicklisp/home/software/alexandria-20241012-git/\t\talexandria\tquicklisp\t2026-01-01\tfalse\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "alexandria",
    events = { "listed" },
  },
}
