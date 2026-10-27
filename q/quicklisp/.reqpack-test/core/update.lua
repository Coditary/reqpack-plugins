return {
  name = "quicklisp update dist and package",
  fixtureRoot = "/tmp/opencode/quicklisp-update-case",
  request = {
    action = "update",
    system = "quicklisp",
    flags = { "data-root=/tmp/opencode/quicklisp-update-case/.reqpack-data" },
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
    { match = "test -f '/tmp/opencode/quicklisp-update-case/.reqpack-data/quicklisp/home/setup.lisp'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "(ql:update-dist \"quicklisp\" :prompt nil)", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "<lua-value>",
      success = "ok",
    },
  },
}
