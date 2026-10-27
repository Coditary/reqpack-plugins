return {
  name = "quicklisp outdated systems when dist update exists",
  fixtureRoot = "/tmp/opencode/quicklisp-outdated-case",
  request = {
    action = "outdated",
    system = "quicklisp",
    flags = { "data-root=/tmp/opencode/quicklisp-outdated-case/.reqpack-data" },
  },
  fixtureDirs = {
    ".reqpack-data/quicklisp/home",
  },
  fixtureFiles = {
    { path = ".reqpack-data/quicklisp/home/setup.lisp", content = ";; quicklisp setup\n" },
  },
  fakeExec = {
    { match = "command -v 'sbcl' >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "test -f '/tmp/opencode/quicklisp-outdated-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(ql-dist:available-update dist)", exitCode = 0, stdout = "REQPACK\tITEM\talexandria\talexandria-20241012-git\t2026-02-01\ttrue\toutdated\tcommon-lisp-system\talexandria\t/tmp/opencode/quicklisp-outdated-case/.reqpack-data/quicklisp/home/software/alexandria-20241012-git/\t\talexandria\tquicklisp\t2026-01-01\tfalse\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "alexandria",
    resultVersion = "alexandria-20241012-git",
    events = { "outdated" },
  },
}
