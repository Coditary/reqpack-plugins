return {
  name = "quicklisp search systems",
  fixtureRoot = "/tmp/opencode/quicklisp-search-case",
  request = {
    action = "search",
    system = "quicklisp",
    prompt = "alex",
    flags = { "data-root=/tmp/opencode/quicklisp-search-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quicklisp/home",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quicklisp/home/setup.lisp", content = ";; quicklisp setup\n" },
  },
  fakeExec = {
    { match = "command -v 'sbcl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/quicklisp-search-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(ql:system-apropos-list \"alex\")", exitCode = 0, stdout = "REQPACK\tITEM\talexandria\talexandria-20241012-git\talexandria-20241012-git\tfalse\tavailable\tcommon-lisp-system\talexandria\t\t\talexandria\tquicklisp\t2026-01-01\tfalse\nREQPACK\tITEM\talexandria-tests\talexandria-20241012-git\talexandria-20241012-git\tfalse\tavailable\tcommon-lisp-system\talexandria\t\t\talexandria\tquicklisp\t2026-01-01\tfalse\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "alexandria",
    resultVersion = "alexandria-20241012-git",
    events = { "searched" },
  },
}
